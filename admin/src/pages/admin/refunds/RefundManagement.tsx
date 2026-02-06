import React, { useState, useEffect, useCallback } from 'react';
import { message, Modal } from 'antd';
import {
  getAdminRefundRequests,
  approveRefundRequest,
  rejectRefundRequest,
  getTaskDisputeTimeline
} from '../../../api';
import { getErrorMessage } from '../../../utils/errorHandler';
import {
  RefundRequest,
  RefundStatus,
  RefundAction,
  DisputeTimeline,
  REFUND_STATUS_LABELS,
  REFUND_STATUS_COLORS,
  TIMELINE_ICONS
} from './types';
import styles from './RefundManagement.module.css';

/**
 * 退款管理组件
 * 提供退款申请列表查看、详情查看、批准/拒绝等功能
 */
const RefundManagement: React.FC = () => {
  // 列表状态
  const [refundRequests, setRefundRequests] = useState<RefundRequest[]>([]);
  const [loading, setLoading] = useState(false);
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);
  const pageSize = 20;

  // 筛选状态
  const [statusFilter, setStatusFilter] = useState<string>('');
  const [searchKeyword, setSearchKeyword] = useState<string>('');

  // 详情弹窗状态
  const [showDetailModal, setShowDetailModal] = useState(false);
  const [selectedRefund, setSelectedRefund] = useState<RefundRequest | null>(null);

  // 处理弹窗状态
  const [showActionModal, setShowActionModal] = useState(false);
  const [refundAction, setRefundAction] = useState<RefundAction>('approve');
  const [adminComment, setAdminComment] = useState('');
  const [refundAmount, setRefundAmount] = useState<number | undefined>();
  const [processing, setProcessing] = useState(false);

  // 时间线弹窗状态
  const [showTimelineModal, setShowTimelineModal] = useState(false);
  const [timeline, setTimeline] = useState<DisputeTimeline | null>(null);
  const [loadingTimeline, setLoadingTimeline] = useState(false);

  // 加载退款申请列表
  const loadRefundRequests = useCallback(async () => {
    try {
      setLoading(true);
      const response = await getAdminRefundRequests({
        skip: (page - 1) * pageSize,
        limit: pageSize,
        status: statusFilter || undefined,
        keyword: searchKeyword.trim() || undefined
      });
      setRefundRequests(response.items || []);
      setTotal(response.total || 0);
    } catch (error: any) {
      message.error(getErrorMessage(error));
    } finally {
      setLoading(false);
    }
  }, [page, statusFilter, searchKeyword]);

  // 初始加载和依赖变化时重新加载
  useEffect(() => {
    loadRefundRequests();
  }, [loadRefundRequests]);

  // 自动刷新待处理申请（每30秒）
  useEffect(() => {
    const refreshInterval = setInterval(() => {
      if (!loading && (!statusFilter || statusFilter === 'pending')) {
        loadRefundRequests();
      }
    }, 30000);

    return () => clearInterval(refreshInterval);
  }, [loading, statusFilter, loadRefundRequests]);

  // 查看详情
  const handleViewDetail = (refund: RefundRequest) => {
    setSelectedRefund(refund);
    setShowDetailModal(true);
  };

  // 查看时间线
  const handleViewTimeline = async (taskId: number) => {
    try {
      setLoadingTimeline(true);
      const data = await getTaskDisputeTimeline(taskId);
      setTimeline(data);
      setShowTimelineModal(true);
    } catch (error: any) {
      message.error(getErrorMessage(error));
    } finally {
      setLoadingTimeline(false);
    }
  };

  // 打开处理弹窗
  const handleOpenAction = (refund: RefundRequest, action: RefundAction) => {
    setSelectedRefund(refund);
    setRefundAction(action);
    setAdminComment('');
    setRefundAmount(undefined);
    setShowActionModal(true);
  };

  // 执行处理操作
  const handleAction = async () => {
    if (!selectedRefund) return;

    if (refundAction === 'reject' && !adminComment.trim()) {
      message.error('请输入拒绝理由');
      return;
    }

    try {
      setProcessing(true);
      if (refundAction === 'approve') {
        await approveRefundRequest(selectedRefund.id, {
          admin_comment: adminComment.trim() || undefined,
          refund_amount: refundAmount
        });
        message.success('退款申请已批准，正在处理退款...');
      } else {
        await rejectRefundRequest(selectedRefund.id, adminComment.trim());
        message.success('退款申请已拒绝');
      }
      setShowActionModal(false);
      setAdminComment('');
      setRefundAmount(undefined);
      setSelectedRefund(null);
      await loadRefundRequests();
    } catch (error: any) {
      message.error(getErrorMessage(error));
    } finally {
      setProcessing(false);
    }
  };

  // 搜索处理
  const handleSearch = () => {
    setPage(1);
    loadRefundRequests();
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

  // 复制任务ID
  const handleCopyTaskId = (taskId: number) => {
    navigator.clipboard.writeText(String(taskId));
    message.success(`任务ID ${taskId} 已复制到剪贴板`);
  };

  // 获取状态样式
  const getStatusStyle = (status: RefundStatus) => {
    const colors = REFUND_STATUS_COLORS[status] || REFUND_STATUS_COLORS.pending;
    return { background: colors.bg, color: colors.color };
  };

  // 获取时间线 actor 样式
  const getActorStyle = (actor: string) => {
    const colors: Record<string, { bg: string; color: string }> = {
      poster: { bg: '#dbeafe', color: '#3b82f6' },
      taker: { bg: '#d1fae5', color: '#10b981' },
      admin: { bg: '#fef3c7', color: '#f59e0b' }
    };
    return colors[actor] || colors.admin;
  };

  const totalPages = Math.ceil(total / pageSize);

  return (
    <div className={styles.container}>
      <h2 className={styles.title}>退款申请管理</h2>

      {/* 筛选和搜索 */}
      <div className={styles.filterContainer}>
        <input
          type="text"
          placeholder="搜索任务标题、发布者姓名或退款原因..."
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
          <option value="approved">已批准</option>
          <option value="rejected">已拒绝</option>
          <option value="processing">处理中</option>
          <option value="completed">已完成</option>
          <option value="cancelled">已取消</option>
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

      {/* 退款申请列表 */}
      <div className={styles.tableContainer}>
        {loading ? (
          <div className={styles.loadingState}>加载中...</div>
        ) : refundRequests.length === 0 ? (
          <div className={styles.emptyState}>
            {searchKeyword ? '未找到匹配的退款申请记录' : '暂无退款申请记录'}
          </div>
        ) : (
          <table className={styles.table}>
            <thead className={styles.tableHeader}>
              <tr>
                <th className={styles.tableHeaderCell}>申请ID</th>
                <th className={styles.tableHeaderCell}>任务ID</th>
                <th className={styles.tableHeaderCell}>任务</th>
                <th className={styles.tableHeaderCell}>发布者</th>
                <th className={styles.tableHeaderCell}>退款原因类型</th>
                <th className={styles.tableHeaderCell}>退款类型</th>
                <th className={styles.tableHeaderCell}>退款金额</th>
                <th className={styles.tableHeaderCell}>状态</th>
                <th className={styles.tableHeaderCell}>创建时间</th>
                <th className={styles.tableHeaderCell}>操作</th>
              </tr>
            </thead>
            <tbody>
              {refundRequests.map((refund) => (
                <tr key={refund.id} className={styles.tableRow}>
                  <td className={styles.tableCell}>{refund.id}</td>
                  <td className={styles.tableCell}>
                    <span
                      className={styles.taskIdLink}
                      onClick={() => handleCopyTaskId(refund.task_id)}
                      title="点击复制任务ID"
                    >
                      #{refund.task_id}
                    </span>
                  </td>
                  <td className={`${styles.tableCell} ${styles.tableCellTruncate}`}>
                    {refund.task?.title || `任务 #${refund.task_id}`}
                  </td>
                  <td className={styles.tableCell}>
                    {refund.poster?.name || refund.poster_id}
                  </td>
                  <td className={styles.tableCell}>
                    {refund.reason_type_display || refund.reason_type || '-'}
                  </td>
                  <td className={styles.tableCell}>
                    <span
                      className={styles.statusBadge}
                      style={{
                        background: refund.refund_type === 'full' ? '#d4edda' : '#fff3cd',
                        color: refund.refund_type === 'full' ? '#155724' : '#856404'
                      }}
                    >
                      {refund.refund_type_display || (refund.refund_type === 'full' ? '全额退款' : refund.refund_type === 'partial' ? '部分退款' : '-')}
                    </span>
                  </td>
                  <td className={styles.tableCell}>
                    {refund.refund_amount != null
                      ? `£${Number(refund.refund_amount).toFixed(2)}${refund.refund_percentage ? ` (${refund.refund_percentage.toFixed(1)}%)` : ''}`
                      : '全额退款'}
                  </td>
                  <td className={styles.tableCell}>
                    <span className={styles.statusBadge} style={getStatusStyle(refund.status)}>
                      {REFUND_STATUS_LABELS[refund.status]}
                    </span>
                  </td>
                  <td className={styles.tableCell}>
                    {new Date(refund.created_at).toLocaleString('zh-CN')}
                  </td>
                  <td className={styles.tableCell}>
                    <div className={styles.actionGroup}>
                      <button
                        onClick={() => handleViewDetail(refund)}
                        className={`${styles.actionBtn} ${styles.btnView}`}
                      >
                        查看
                      </button>
                      <button
                        onClick={() => handleViewTimeline(refund.task_id)}
                        disabled={loadingTimeline}
                        className={`${styles.actionBtn} ${styles.btnTimeline}`}
                      >
                        {loadingTimeline ? '加载中...' : '争议详情'}
                      </button>
                      {refund.status === 'pending' && (
                        <>
                          <button
                            onClick={() => handleOpenAction(refund, 'approve')}
                            className={`${styles.actionBtn} ${styles.btnApprove}`}
                          >
                            批准
                          </button>
                          <button
                            onClick={() => handleOpenAction(refund, 'reject')}
                            className={`${styles.actionBtn} ${styles.btnReject}`}
                          >
                            拒绝
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

      {/* 退款申请详情弹窗 */}
      <Modal
        title={`退款申请详情 #${selectedRefund?.id || ''}`}
        open={showDetailModal}
        onCancel={() => {
          setShowDetailModal(false);
          setSelectedRefund(null);
        }}
        footer={null}
        width={800}
      >
        {selectedRefund && (
          <div style={{ padding: '20px' }}>
            {/* 任务信息 */}
            <div className={styles.modalSection}>
              <h3 className={styles.modalSectionTitle}>任务信息</h3>
              {selectedRefund.task && (
                <>
                  <div className={styles.modalField}>
                    <span className={styles.modalLabel}>任务标题：</span>
                    <span className={styles.modalValue}>
                      {selectedRefund.task.title || `任务 #${selectedRefund.task_id}`}
                    </span>
                  </div>
                  <div className={styles.modalField}>
                    <span className={styles.modalLabel}>任务金额：</span>
                    <span className={styles.modalValue}>
                      £{selectedRefund.task.agreed_reward || selectedRefund.task.base_reward || 0}
                    </span>
                  </div>
                  <div className={styles.modalField}>
                    <span className={styles.modalLabel}>支付状态：</span>
                    <span
                      className={styles.statusBadge}
                      style={{
                        background: selectedRefund.task.is_paid ? '#d4edda' : '#f8d7da',
                        color: selectedRefund.task.is_paid ? '#155724' : '#721c24',
                        marginLeft: '8px'
                      }}
                    >
                      {selectedRefund.task.is_paid ? '✅ 已支付' : '⏳ 未支付'}
                    </span>
                  </div>
                </>
              )}
            </div>

            {/* 退款申请信息 */}
            <div className={styles.modalSection}>
              <h3 className={styles.modalSectionTitle}>退款申请信息</h3>
              <div className={styles.modalField}>
                <span className={styles.modalLabel}>退款原因类型：</span>
                <span
                  className={styles.statusBadge}
                  style={{ background: '#e3f2fd', color: '#1976d2', marginLeft: '8px' }}
                >
                  {selectedRefund.reason_type_display || selectedRefund.reason_type || '未知'}
                </span>
              </div>
              <div className={styles.modalField}>
                <span className={styles.modalLabel}>退款类型：</span>
                <span
                  className={styles.statusBadge}
                  style={{
                    background: selectedRefund.refund_type === 'full' ? '#d4edda' : '#fff3cd',
                    color: selectedRefund.refund_type === 'full' ? '#155724' : '#856404',
                    marginLeft: '8px'
                  }}
                >
                  {selectedRefund.refund_type_display || (selectedRefund.refund_type === 'full' ? '全额退款' : '部分退款')}
                </span>
              </div>
              <div className={styles.modalField}>
                <span className={styles.modalLabel}>退款原因详细说明：</span>
                <div className={styles.modalTextBlock}>{selectedRefund.reason}</div>
              </div>
              <div className={styles.modalField}>
                <span className={styles.modalLabel}>申请退款金额：</span>
                <span className={styles.modalValue}>
                  {selectedRefund.refund_amount != null
                    ? `£${Number(selectedRefund.refund_amount).toFixed(2)}${selectedRefund.refund_percentage ? ` (${selectedRefund.refund_percentage.toFixed(1)}%)` : ''}`
                    : '全额退款'}
                </span>
              </div>
              {selectedRefund.evidence_files && selectedRefund.evidence_files.length > 0 && (
                <div className={styles.modalField}>
                  <span className={styles.modalLabel}>证据文件：</span>
                  <div className={styles.evidenceFiles}>
                    {selectedRefund.evidence_files.map((fileId, index) => (
                      <a
                        key={index}
                        href={`/api/private-file?file=${fileId}`}
                        target="_blank"
                        rel="noopener noreferrer"
                        className={styles.evidenceLink}
                      >
                        文件 {index + 1}
                      </a>
                    ))}
                  </div>
                </div>
              )}
              <div className={styles.modalField}>
                <span className={styles.modalLabel}>状态：</span>
                <span className={styles.statusBadge} style={getStatusStyle(selectedRefund.status)}>
                  {REFUND_STATUS_LABELS[selectedRefund.status]}
                </span>
              </div>
              {selectedRefund.admin_comment && (
                <div className={styles.modalField}>
                  <span className={styles.modalLabel}>管理员备注：</span>
                  <div className={styles.modalTextBlock}>{selectedRefund.admin_comment}</div>
                </div>
              )}
              {selectedRefund.reviewed_at && (
                <div className={styles.modalField}>
                  <span className={styles.modalLabel}>审核时间：</span>
                  <span className={styles.modalValue}>
                    {new Date(selectedRefund.reviewed_at).toLocaleString('zh-CN')}
                  </span>
                </div>
              )}
              <div className={styles.modalField}>
                <span className={styles.modalLabel}>创建时间：</span>
                <span className={styles.modalValue}>
                  {new Date(selectedRefund.created_at).toLocaleString('zh-CN')}
                </span>
              </div>
            </div>
          </div>
        )}
      </Modal>

      {/* 时间线弹窗 */}
      <Modal
        title={`争议详情 - 任务 #${timeline?.task_id || ''}`}
        open={showTimelineModal}
        onCancel={() => {
          setShowTimelineModal(false);
          setTimeline(null);
        }}
        footer={null}
        width={900}
      >
        {timeline && (
          <div style={{ padding: '20px', maxHeight: '70vh', overflow: 'auto' }}>
            <div style={{ marginBottom: '20px', padding: '12px', background: '#f3f4f6', borderRadius: '8px' }}>
              <strong>任务标题：</strong> {timeline.task_title}
            </div>

            {timeline.timeline && timeline.timeline.length > 0 ? (
              <div className={styles.timeline}>
                {timeline.timeline.map((item, index) => {
                  const isLast = index === timeline.timeline.length - 1;
                  const actorStyle = getActorStyle(item.actor);
                  const actorName = item.actor === 'poster' ? '发布者' :
                    item.actor === 'taker' ? '接单者' :
                      (item.reviewer_name || item.resolver_name || '管理员');
                  const icon = TIMELINE_ICONS[item.type] || '📋';

                  return (
                    <div key={index} className={styles.timelineItem}>
                      {!isLast && <div className={styles.timelineLine}></div>}
                      <div
                        className={styles.timelineDot}
                        style={{ background: actorStyle.bg }}
                      >
                        {icon}
                      </div>
                      <div className={styles.timelineContent}>
                        <div className={styles.timelineHeader}>
                          <span
                            className={styles.timelineActor}
                            style={{ background: actorStyle.bg, color: actorStyle.color }}
                          >
                            {actorName}
                          </span>
                          <span className={styles.timelineTime}>
                            {new Date(item.timestamp).toLocaleString('zh-CN')}
                          </span>
                        </div>
                        <div className={styles.timelineBody}>
                          {item.content || item.status || '-'}
                        </div>
                      </div>
                    </div>
                  );
                })}
              </div>
            ) : (
              <div style={{ textAlign: 'center', color: '#999', padding: '40px' }}>
                暂无争议/退款记录
              </div>
            )}
          </div>
        )}
      </Modal>

      {/* 处理退款申请弹窗 */}
      <Modal
        title={refundAction === 'approve' ? '批准退款申请' : '拒绝退款申请'}
        open={showActionModal}
        onCancel={() => {
          setShowActionModal(false);
          setAdminComment('');
          setRefundAmount(undefined);
          setSelectedRefund(null);
        }}
        onOk={handleAction}
        confirmLoading={processing}
        okText={refundAction === 'approve' ? '批准' : '拒绝'}
        cancelText="取消"
        width={600}
      >
        {selectedRefund && (
          <div className={styles.actionForm}>
            <div className={styles.actionFormField}>
              <span className={styles.modalLabel}>任务：</span>
              <span className={styles.modalValue}>
                {selectedRefund.task?.title || `任务 #${selectedRefund.task_id}`}
              </span>
            </div>
            <div className={styles.actionFormField}>
              <span className={styles.modalLabel}>申请退款金额：</span>
              <span className={styles.modalValue}>
                {selectedRefund.refund_amount != null
                  ? `£${Number(selectedRefund.refund_amount).toFixed(2)}`
                  : '全额退款'}
              </span>
            </div>
            {refundAction === 'approve' && (
              <div className={styles.actionFormField}>
                <label className={styles.actionFormLabel}>
                  实际退款金额（可选，留空则按申请金额退款）：
                </label>
                <input
                  type="number"
                  step="0.01"
                  min="0"
                  value={refundAmount || ''}
                  onChange={(e) => setRefundAmount(e.target.value ? parseFloat(e.target.value) : undefined)}
                  placeholder="£0.00"
                  className={styles.actionFormInput}
                />
              </div>
            )}
            <div className={styles.actionFormField}>
              <label className={styles.actionFormLabel}>
                {refundAction === 'approve' ? '管理员备注（可选）：' : '拒绝理由：'}
              </label>
              <textarea
                value={adminComment}
                onChange={(e) => setAdminComment(e.target.value)}
                placeholder={refundAction === 'approve' ? '请输入备注...' : '请输入拒绝理由...'}
                rows={4}
                className={styles.actionFormTextarea}
              />
            </div>
          </div>
        )}
      </Modal>
    </div>
  );
};

export default RefundManagement;
