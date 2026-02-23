import React, { useState, useCallback, useEffect } from 'react';
import { message, Modal } from 'antd';
import dayjs from 'dayjs';
import { useAdminTable, useModalForm } from '../../../hooks';
import { AdminTable, AdminPagination, Column } from '../../../components/admin';
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
import { exportToCSV, ExportColumn } from '../../../utils/exportUtils';
import styles from './RefundManagement.module.css';

const REFUND_EXPORT_COLUMNS: ExportColumn[] = [
  { key: 'id', label: 'ID' },
  { key: 'task_id', label: '任务ID' },
  { key: 'poster_id', label: '发布者ID' },
  { key: 'reason_type', label: '退款原因类型' },
  { key: 'refund_type', label: '退款类型', format: v => v === 'full' ? '全额退款' : v === 'partial' ? '部分退款' : '-' },
  { key: 'refund_amount', label: '退款金额', format: v => v != null ? `£${Number(v).toFixed(2)}` : '全额退款' },
  { key: 'status', label: '状态', format: v => REFUND_STATUS_LABELS[v as RefundStatus] || v },
  { key: 'created_at', label: '申请时间', format: v => dayjs(v).format('YYYY-MM-DD HH:mm') },
];

interface ActionForm {
  action: RefundAction;
  adminComment: string;
  refundAmount: number | undefined;
  refund: RefundRequest | null;
}

const initialActionForm: ActionForm = {
  action: 'approve',
  adminComment: '',
  refundAmount: undefined,
  refund: null,
};

/**
 * 退款管理组件
 * 提供退款申请列表查看、详情查看、批准/拒绝等功能
 */
const RefundManagement: React.FC = () => {
  const [statusFilter, setStatusFilter] = useState<string>('');
  const [searchKeyword, setSearchKeyword] = useState<string>('');

  // 详情弹窗状态（只读，不提交）
  const [showDetailModal, setShowDetailModal] = useState(false);
  const [selectedRefund, setSelectedRefund] = useState<RefundRequest | null>(null);

  // 时间线弹窗状态（只读，不提交）
  const [showTimelineModal, setShowTimelineModal] = useState(false);
  const [timeline, setTimeline] = useState<DisputeTimeline | null>(null);
  const [loadingTimeline, setLoadingTimeline] = useState(false);

  // 获取退款申请列表
  const fetchRefundRequests = useCallback(async ({ page, pageSize, filters }: { page: number; pageSize: number; searchTerm?: string; filters?: Record<string, any> }) => {
    const response = await getAdminRefundRequests({
      skip: (page - 1) * pageSize,
      limit: pageSize,
      status: filters?.status || undefined,
      keyword: filters?.keyword || undefined,
    });
    return {
      data: response.items || [],
      total: response.total || 0,
    };
  }, []);

  const handleFetchError = useCallback((error: any) => {
    message.error(getErrorMessage(error));
  }, []);

  const table = useAdminTable<RefundRequest>({
    fetchData: fetchRefundRequests,
    initialPageSize: 20,
    onError: handleFetchError,
  });

  // 处理弹窗（带提交，使用 useModalForm）
  const actionModal = useModalForm<ActionForm>({
    initialValues: initialActionForm,
    onSubmit: async (values) => {
      if (!values.refund) return;

      if (values.action === 'reject' && !values.adminComment.trim()) {
        message.error('请输入拒绝理由');
        throw new Error('请输入拒绝理由');
      }

      if (values.action === 'approve') {
        await approveRefundRequest(values.refund.id, {
          admin_comment: values.adminComment.trim() || undefined,
          refund_amount: values.refundAmount
        });
        message.success('退款申请已批准，正在处理退款...');
      } else {
        await rejectRefundRequest(values.refund.id, values.adminComment.trim());
        message.success('退款申请已拒绝');
      }
      table.refresh();
    },
    onError: (error) => {
      message.error(getErrorMessage(error));
    },
  });

  // 自动刷新待处理申请（每30秒）
  useEffect(() => {
    const refreshInterval = setInterval(() => {
      if (!table.loading && (!statusFilter || statusFilter === 'pending')) {
        table.refresh();
      }
    }, 30000);
    return () => clearInterval(refreshInterval);
  }, [table.loading, statusFilter, table.refresh]);

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
    actionModal.open({ action, adminComment: '', refundAmount: undefined, refund });
  };

  // 搜索处理
  const handleSearch = () => {
    table.setFilters({
      status: statusFilter || undefined,
      keyword: searchKeyword.trim() || undefined,
    });
    table.setCurrentPage(1);
  };

  // 清除搜索
  const handleClearSearch = () => {
    setSearchKeyword('');
    table.setFilters({
      status: statusFilter || undefined,
      keyword: undefined,
    });
    table.setCurrentPage(1);
  };

  // 状态筛选变化
  const handleStatusFilterChange = (value: string) => {
    setStatusFilter(value);
    table.setFilters({
      status: value || undefined,
      keyword: searchKeyword.trim() || undefined,
    });
    table.setCurrentPage(1);
  };

  const handleExport = () => {
    exportToCSV(
      table.data as Record<string, any>[],
      `refunds-${dayjs().format('YYYY-MM-DD')}`,
      REFUND_EXPORT_COLUMNS
    );
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

  // 表格列定义
  const columns: Column<RefundRequest>[] = [
    {
      key: 'id',
      title: '申请ID',
      dataIndex: 'id',
      width: 80,
    },
    {
      key: 'task_id',
      title: '任务ID',
      width: 90,
      render: (_, record) => (
        <span
          className={styles.taskIdLink}
          onClick={() => handleCopyTaskId(record.task_id)}
          title="点击复制任务ID"
        >
          #{record.task_id}
        </span>
      ),
    },
    {
      key: 'task_title',
      title: '任务',
      width: 180,
      render: (_, record) => (
        <span className={styles.tableCellTruncate}>
          {record.task?.title || `任务 #${record.task_id}`}
        </span>
      ),
    },
    {
      key: 'poster',
      title: '发布者',
      width: 120,
      render: (_, record) => record.poster?.name || record.poster_id,
    },
    {
      key: 'reason_type',
      title: '退款原因类型',
      width: 120,
      render: (_, record) => record.reason_type_display || record.reason_type || '-',
    },
    {
      key: 'refund_type',
      title: '退款类型',
      width: 100,
      render: (_, record) => (
        <span
          className={styles.statusBadge}
          style={{
            background: record.refund_type === 'full' ? '#d4edda' : '#fff3cd',
            color: record.refund_type === 'full' ? '#155724' : '#856404'
          }}
        >
          {record.refund_type_display || (record.refund_type === 'full' ? '全额退款' : record.refund_type === 'partial' ? '部分退款' : '-')}
        </span>
      ),
    },
    {
      key: 'refund_amount',
      title: '退款金额',
      width: 130,
      render: (_, record) =>
        record.refund_amount != null
          ? `£${Number(record.refund_amount).toFixed(2)}${record.refund_percentage ? ` (${record.refund_percentage.toFixed(1)}%)` : ''}`
          : '全额退款',
    },
    {
      key: 'status',
      title: '状态',
      dataIndex: 'status',
      width: 100,
      render: (value) => (
        <span className={styles.statusBadge} style={getStatusStyle(value as RefundStatus)}>
          {REFUND_STATUS_LABELS[value as RefundStatus]}
        </span>
      ),
    },
    {
      key: 'created_at',
      title: '创建时间',
      dataIndex: 'created_at',
      width: 160,
      render: (value) => new Date(value).toLocaleString('zh-CN'),
    },
    {
      key: 'actions',
      title: '操作',
      width: 200,
      align: 'center',
      render: (_, record) => (
        <div className={styles.actionGroup}>
          <button
            onClick={() => handleViewDetail(record)}
            className={`${styles.actionBtn} ${styles.btnView}`}
          >
            查看
          </button>
          <button
            onClick={() => handleViewTimeline(record.task_id)}
            disabled={loadingTimeline}
            className={`${styles.actionBtn} ${styles.btnTimeline}`}
          >
            {loadingTimeline ? '加载中...' : '争议详情'}
          </button>
          {record.status === 'pending' && (
            <>
              <button
                onClick={() => handleOpenAction(record, 'approve')}
                className={`${styles.actionBtn} ${styles.btnApprove}`}
              >
                批准
              </button>
              <button
                onClick={() => handleOpenAction(record, 'reject')}
                className={`${styles.actionBtn} ${styles.btnReject}`}
              >
                拒绝
              </button>
            </>
          )}
        </div>
      ),
    },
  ];

  return (
    <div className={styles.container}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '16px' }}>
        <h2 className={styles.title} style={{ margin: 0 }}>退款申请管理</h2>
        <button
          onClick={handleExport}
          disabled={table.data.length === 0}
          style={{
            padding: '8px 16px',
            border: '1px solid #52c41a',
            background: 'white',
            color: '#52c41a',
            borderRadius: '4px',
            cursor: 'pointer',
            fontSize: '14px',
          }}
        >
          导出 CSV
        </button>
      </div>

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
      <AdminTable
        columns={columns}
        data={table.data}
        loading={table.loading}
        refreshing={table.fetching}
        rowKey="id"
        emptyText={searchKeyword ? '未找到匹配的退款申请记录' : '暂无退款申请记录'}
      />

      {/* 分页 */}
      <AdminPagination
        currentPage={table.currentPage}
        totalPages={table.totalPages}
        total={table.total}
        pageSize={table.pageSize}
        onPageChange={table.setCurrentPage}
        onPageSizeChange={table.setPageSize}
      />

      {/* 退款申请详情弹窗（只读） */}
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

      {/* 时间线弹窗（只读） */}
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
        title={actionModal.formData.action === 'approve' ? '批准退款申请' : '拒绝退款申请'}
        open={actionModal.isOpen}
        onCancel={actionModal.close}
        onOk={actionModal.handleSubmit}
        confirmLoading={actionModal.loading}
        okText={actionModal.formData.action === 'approve' ? '批准' : '拒绝'}
        cancelText="取消"
        width={600}
      >
        {actionModal.formData.refund && (
          <div className={styles.actionForm}>
            <div className={styles.actionFormField}>
              <span className={styles.modalLabel}>任务：</span>
              <span className={styles.modalValue}>
                {actionModal.formData.refund.task?.title || `任务 #${actionModal.formData.refund.task_id}`}
              </span>
            </div>
            <div className={styles.actionFormField}>
              <span className={styles.modalLabel}>申请退款金额：</span>
              <span className={styles.modalValue}>
                {actionModal.formData.refund.refund_amount != null
                  ? `£${Number(actionModal.formData.refund.refund_amount).toFixed(2)}`
                  : '全额退款'}
              </span>
            </div>
            {actionModal.formData.action === 'approve' && (
              <div className={styles.actionFormField}>
                <label className={styles.actionFormLabel}>
                  实际退款金额（可选，留空则按申请金额退款）：
                </label>
                <input
                  type="number"
                  step="0.01"
                  min="0"
                  value={actionModal.formData.refundAmount || ''}
                  onChange={(e) => actionModal.updateField('refundAmount', e.target.value ? parseFloat(e.target.value) : undefined)}
                  placeholder="£0.00"
                  className={styles.actionFormInput}
                />
              </div>
            )}
            <div className={styles.actionFormField}>
              <label className={styles.actionFormLabel}>
                {actionModal.formData.action === 'approve' ? '管理员备注（可选）：' : '拒绝理由：'}
              </label>
              <textarea
                value={actionModal.formData.adminComment}
                onChange={(e) => actionModal.updateField('adminComment', e.target.value)}
                placeholder={actionModal.formData.action === 'approve' ? '请输入备注...' : '请输入拒绝理由...'}
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
