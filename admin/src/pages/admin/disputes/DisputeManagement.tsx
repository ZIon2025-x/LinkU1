import React, { useState, useCallback, useEffect } from 'react';
import { message, Modal } from 'antd';
import { useAdminTable, useModalForm } from '../../../hooks';
import { AdminTable, AdminPagination, Column } from '../../../components/admin';
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

interface ActionForm {
  action: DisputeAction;
  resolutionNote: string;
  dispute: TaskDispute | null;
}

const initialActionForm: ActionForm = {
  action: 'resolve',
  resolutionNote: '',
  dispute: null,
};

/**
 * 争议管理组件
 * 提供任务争议列表查看、详情查看、解决/驳回等功能
 */
const DisputeManagement: React.FC = () => {
  const [statusFilter, setStatusFilter] = useState<string>('');
  const [searchKeyword, setSearchKeyword] = useState<string>('');

  // 详情弹窗状态（只读，不提交，用简单 state）
  const [showDetailModal, setShowDetailModal] = useState(false);
  const [selectedDispute, setSelectedDispute] = useState<TaskDispute | null>(null);

  // 获取争议列表
  const fetchDisputes = useCallback(async ({ page, pageSize, filters }: { page: number; pageSize: number; searchTerm?: string; filters?: Record<string, any> }) => {
    const response = await getAdminTaskDisputes({
      skip: (page - 1) * pageSize,
      limit: pageSize,
      status: filters?.status || undefined,
      keyword: filters?.keyword || undefined,
    });
    return {
      data: response.disputes || [],
      total: response.total || 0,
    };
  }, []);

  const handleFetchError = useCallback((error: any) => {
    message.error(getErrorMessage(error));
  }, []);

  const table = useAdminTable<TaskDispute>({
    fetchData: fetchDisputes,
    initialPageSize: 20,
    onError: handleFetchError,
  });

  // 处理弹窗（带提交，使用 useModalForm）
  const actionModal = useModalForm<ActionForm>({
    initialValues: initialActionForm,
    onSubmit: async (values) => {
      if (!values.dispute || !values.resolutionNote.trim()) {
        message.error('请输入处理备注');
        throw new Error('请输入处理备注');
      }
      if (values.action === 'resolve') {
        await resolveTaskDispute(values.dispute.id, values.resolutionNote.trim());
        message.success('争议已解决');
      } else {
        await dismissTaskDispute(values.dispute.id, values.resolutionNote.trim());
        message.success('争议已驳回');
      }
      table.refresh();
    },
    onError: (error) => {
      message.error(getErrorMessage(error));
    },
  });

  // 自动刷新待处理争议（每30秒）
  useEffect(() => {
    const refreshInterval = setInterval(() => {
      if (!table.loading && (!statusFilter || statusFilter === 'pending')) {
        table.refresh();
      }
    }, 30000);
    return () => clearInterval(refreshInterval);
  }, [table.loading, statusFilter, table.refresh]);

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
    actionModal.open({ action, resolutionNote: '', dispute });
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

  // 表格列定义
  const columns: Column<TaskDispute>[] = [
    {
      key: 'id',
      title: 'ID',
      dataIndex: 'id',
      width: 80,
    },
    {
      key: 'task',
      title: '任务',
      width: 200,
      render: (_, record) => (
        <span className={styles.tableCellTruncate}>
          {record.task_title} (#{record.task_id})
        </span>
      ),
    },
    {
      key: 'poster_name',
      title: '发布者',
      dataIndex: 'poster_name',
      width: 120,
    },
    {
      key: 'reason',
      title: '争议原因',
      dataIndex: 'reason',
      width: 250,
      render: (value) => <span className={styles.tableCellReason}>{value}</span>,
    },
    {
      key: 'status',
      title: '状态',
      dataIndex: 'status',
      width: 100,
      render: (value) => (
        <span className={styles.statusBadge} style={getStatusStyle(value as DisputeStatus)}>
          {DISPUTE_STATUS_LABELS[value as DisputeStatus]}
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
      width: 180,
      align: 'center',
      render: (_, record) => (
        <div className={styles.actionGroup}>
          <button
            onClick={() => handleViewDetail(record.id)}
            className={`${styles.actionBtn} ${styles.btnView}`}
          >
            查看
          </button>
          {record.status === 'pending' && (
            <>
              <button
                onClick={() => handleOpenAction(record, 'resolve')}
                className={`${styles.actionBtn} ${styles.btnResolve}`}
              >
                解决
              </button>
              <button
                onClick={() => handleOpenAction(record, 'dismiss')}
                className={`${styles.actionBtn} ${styles.btnDismiss}`}
              >
                驳回
              </button>
            </>
          )}
        </div>
      ),
    },
  ];

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
      <AdminTable
        columns={columns}
        data={table.data}
        loading={table.loading}
        rowKey="id"
        emptyText={searchKeyword ? '未找到匹配的争议记录' : '暂无争议记录'}
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

      {/* 争议详情弹窗（只读） */}
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
        title={actionModal.formData.action === 'resolve' ? '解决争议' : '驳回争议'}
        open={actionModal.isOpen}
        onCancel={actionModal.close}
        onOk={actionModal.handleSubmit}
        confirmLoading={actionModal.loading}
        okText={actionModal.formData.action === 'resolve' ? '解决' : '驳回'}
        cancelText="取消"
        width={600}
      >
        {actionModal.formData.dispute && (
          <div className={styles.actionForm}>
            <div className={styles.actionFormField}>
              <span className={styles.modalLabel}>任务：</span>
              <span className={styles.modalValue}>
                {actionModal.formData.dispute.task_title || `任务 #${actionModal.formData.dispute.task_id}`}
              </span>
            </div>
            <div className={styles.actionFormField}>
              <span className={styles.modalLabel}>争议原因：</span>
              <div className={styles.modalTextBlock}>{actionModal.formData.dispute.reason}</div>
            </div>
            <div className={styles.actionFormField}>
              <label className={styles.actionFormLabel}>
                {actionModal.formData.action === 'resolve' ? '处理备注' : '驳回理由'}：
              </label>
              <textarea
                value={actionModal.formData.resolutionNote}
                onChange={(e) => actionModal.updateField('resolutionNote', e.target.value)}
                placeholder={actionModal.formData.action === 'resolve' ? '请输入处理备注...' : '请输入驳回理由...'}
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
