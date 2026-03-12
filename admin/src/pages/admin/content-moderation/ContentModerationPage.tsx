import React, { useState, useCallback } from 'react';
import { message } from 'antd';
import { useAdminTable, useModalForm } from '../../../hooks';
import { AdminTable, AdminPagination, StatusBadge, Column } from '../../../components/admin';
import {
  getSensitiveWords,
  createSensitiveWord,
  updateSensitiveWord,
  deleteSensitiveWord,
  batchImportSensitiveWords,
  getHomophoneMappings,
  createHomophoneMapping,
  deleteHomophoneMapping,
  getContentReviews,
  reviewContent,
  getFilterLogs,
} from '../../../api';
import { getErrorMessage } from '../../../utils/errorHandler';
import {
  SensitiveWord,
  SensitiveWordForm,
  initialSensitiveWordForm,
  HomophoneMapping,
  HomophoneMappingForm,
  initialHomophoneForm,
  ContentReview,
  FilterLog,
  CATEGORIES,
  CATEGORY_MAP,
  CONTENT_TYPE_MAP,
  ACTION_MAP,
} from './types';
import styles from './ContentModeration.module.css';

type TabKey = 'words' | 'homophones' | 'reviews' | 'logs';

export const ContentModerationPage: React.FC = () => {
  const [activeTab, setActiveTab] = useState<TabKey>('words');

  return (
    <div className={styles.container}>
      <div className={styles.header}>
        <h2 className={styles.title}>内容审核管理</h2>
      </div>

      <div className={styles.tabs}>
        {([
          { key: 'words' as TabKey, label: '敏感词管理' },
          { key: 'homophones' as TabKey, label: '谐音映射' },
          { key: 'reviews' as TabKey, label: '审核队列' },
          { key: 'logs' as TabKey, label: '过滤日志' },
        ]).map(tab => (
          <button
            key={tab.key}
            className={`${styles.tab} ${activeTab === tab.key ? styles.tabActive : ''}`}
            onClick={() => setActiveTab(tab.key)}
          >
            {tab.label}
          </button>
        ))}
      </div>

      {activeTab === 'words' && <SensitiveWordsTab />}
      {activeTab === 'homophones' && <HomophonesTab />}
      {activeTab === 'reviews' && <ReviewsTab />}
      {activeTab === 'logs' && <LogsTab />}
    </div>
  );
};

// ═══════════════════════════════════════════════════════════════
// Tab 1: 敏感词管理
// ═══════════════════════════════════════════════════════════════

const SensitiveWordsTab: React.FC = () => {
  const [categoryFilter, setCategoryFilter] = useState('');
  const [activeFilter, setActiveFilter] = useState('');
  const [keyword, setKeyword] = useState('');
  const [showBatchModal, setShowBatchModal] = useState(false);
  const [batchText, setBatchText] = useState('');
  const [batchCategory, setBatchCategory] = useState('illegal');
  const [batchLevel, setBatchLevel] = useState<'mask' | 'review'>('review');
  const [batchLoading, setBatchLoading] = useState(false);

  const fetchWords = useCallback(async ({ page, pageSize, filters }: any) => {
    const response = await getSensitiveWords({
      skip: (page - 1) * pageSize,
      limit: pageSize,
      category: filters?.category,
      is_active: filters?.is_active,
      keyword: filters?.keyword,
    });
    return { data: response.items || [], total: response.total || 0 };
  }, []);

  const table = useAdminTable<SensitiveWord>({
    fetchData: fetchWords,
    initialPageSize: 20,
    onError: (err) => message.error(getErrorMessage(err)),
  });

  const modal = useModalForm<SensitiveWordForm>({
    initialValues: initialSensitiveWordForm,
    onSubmit: async (values, isEdit) => {
      if (isEdit && values.id) {
        await updateSensitiveWord(values.id, values);
        message.success('更新成功');
      } else {
        await createSensitiveWord(values);
        message.success('创建成功');
      }
      table.refresh();
    },
    onError: (err) => message.error(getErrorMessage(err)),
  });

  const handleDelete = async (word: SensitiveWord) => {
    if (!window.confirm(`确定删除敏感词"${word.word}"吗？`)) return;
    try {
      await deleteSensitiveWord(word.id);
      message.success('删除成功');
      table.refresh();
    } catch (err) {
      message.error(getErrorMessage(err));
    }
  };

  const handleEdit = (word: SensitiveWord) => {
    modal.open({
      id: word.id,
      word: word.word,
      category: word.category,
      level: word.level,
      is_active: word.is_active,
    });
  };

  const handleBatchImport = async () => {
    const words = batchText
      .split('\n')
      .map(w => w.trim())
      .filter(w => w.length > 0);
    if (words.length === 0) {
      message.warning('请输入至少一个敏感词');
      return;
    }
    setBatchLoading(true);
    try {
      const result = await batchImportSensitiveWords({
        words: words.map(w => ({
          word: w,
          category: batchCategory,
          level: batchLevel,
          is_active: true,
        })),
      });
      message.success(`成功添加 ${result.created_count} 个，跳过 ${result.skipped_count} 个重复词`);
      setShowBatchModal(false);
      setBatchText('');
      table.refresh();
    } catch (err) {
      message.error(getErrorMessage(err));
    } finally {
      setBatchLoading(false);
    }
  };

  const applyFilters = () => {
    table.setFilters({
      category: categoryFilter || undefined,
      is_active: activeFilter === '' ? undefined : activeFilter === 'true',
      keyword: keyword || undefined,
    });
  };

  const columns: Column<SensitiveWord>[] = [
    { key: 'id', title: 'ID', dataIndex: 'id', width: 70 },
    { key: 'word', title: '敏感词', dataIndex: 'word', width: 150 },
    {
      key: 'category',
      title: '分类',
      dataIndex: 'category',
      width: 100,
      render: (value) => CATEGORY_MAP[value] || value,
    },
    {
      key: 'level',
      title: '处理方式',
      dataIndex: 'level',
      width: 100,
      render: (value) => (
        <span className={`${styles.badge} ${value === 'mask' ? styles.badgeMask : styles.badgeReview}`}>
          {value === 'mask' ? '遮蔽替换' : '人工审核'}
        </span>
      ),
    },
    {
      key: 'is_active',
      title: '状态',
      dataIndex: 'is_active',
      width: 80,
      render: (value) => (
        <span className={`${styles.badge} ${value ? styles.badgeActive : styles.badgeInactive}`}>
          {value ? '启用' : '停用'}
        </span>
      ),
    },
    {
      key: 'created_at',
      title: '创建时间',
      dataIndex: 'created_at',
      width: 160,
      render: (value) => value ? new Date(value).toLocaleString('zh-CN') : '-',
    },
    {
      key: 'actions',
      title: '操作',
      width: 150,
      align: 'center',
      render: (_, record) => (
        <div className={styles.actions}>
          <button className={styles.btnEdit} onClick={() => handleEdit(record)}>编辑</button>
          <button className={styles.btnDelete} onClick={() => handleDelete(record)}>删除</button>
        </div>
      ),
    },
  ];

  return (
    <>
      <div className={styles.filters}>
        <div className={styles.filterGroup}>
          <label>分类：</label>
          <select className={styles.select} value={categoryFilter} onChange={e => setCategoryFilter(e.target.value)}>
            <option value="">全部分类</option>
            {CATEGORIES.map(c => <option key={c.value} value={c.value}>{c.label}</option>)}
          </select>
        </div>
        <div className={styles.filterGroup}>
          <label>状态：</label>
          <select className={styles.select} value={activeFilter} onChange={e => setActiveFilter(e.target.value)}>
            <option value="">全部</option>
            <option value="true">启用</option>
            <option value="false">停用</option>
          </select>
        </div>
        <div className={styles.filterGroup}>
          <label>搜索：</label>
          <input
            className={styles.input}
            placeholder="搜索敏感词..."
            value={keyword}
            onChange={e => setKeyword(e.target.value)}
            onKeyDown={e => e.key === 'Enter' && applyFilters()}
          />
        </div>
        <button className={styles.btnCreate} onClick={applyFilters}>筛选</button>
        <button className={styles.btnCreate} onClick={() => modal.open(initialSensitiveWordForm, true)}>+ 添加</button>
        <button className={styles.btnCreate} style={{ background: '#28a745' }} onClick={() => setShowBatchModal(true)}>批量导入</button>
      </div>

      <AdminTable columns={columns} data={table.data} loading={table.loading} refreshing={table.fetching} rowKey="id" emptyText="暂无敏感词" />
      <AdminPagination currentPage={table.currentPage} totalPages={table.totalPages} total={table.total} pageSize={table.pageSize} onPageChange={table.setCurrentPage} onPageSizeChange={table.setPageSize} />

      {/* 单个添加/编辑模态框 */}
      {modal.isOpen && (
        <div className={styles.modalOverlay} onClick={modal.close}>
          <div className={styles.modal} onClick={e => e.stopPropagation()}>
            <h3 className={styles.modalTitle}>{modal.isEdit ? '编辑敏感词' : '添加敏感词'}</h3>
            <div className={styles.formGroup}>
              <label>敏感词 *</label>
              <input value={modal.formData.word} onChange={e => modal.setFormData({ ...modal.formData, word: e.target.value })} placeholder="输入敏感词" />
            </div>
            <div className={styles.formGroup}>
              <label>分类 *</label>
              <select value={modal.formData.category} onChange={e => modal.setFormData({ ...modal.formData, category: e.target.value })}>
                {CATEGORIES.map(c => <option key={c.value} value={c.value}>{c.label}</option>)}
              </select>
            </div>
            <div className={styles.formGroup}>
              <label>处理方式 *</label>
              <select value={modal.formData.level} onChange={e => modal.setFormData({ ...modal.formData, level: e.target.value as 'mask' | 'review' })}>
                <option value="review">人工审核（隐藏内容等待审批）</option>
                <option value="mask">遮蔽替换（自动替换为***）</option>
              </select>
            </div>
            <div className={styles.formGroup}>
              <div className={styles.checkboxGroup}>
                <input type="checkbox" checked={modal.formData.is_active} onChange={e => modal.setFormData({ ...modal.formData, is_active: e.target.checked })} />
                <label>启用</label>
              </div>
            </div>
            <div className={styles.modalFooter}>
              <button className={styles.btnCancel} onClick={modal.close}>取消</button>
              <button className={styles.btnSubmit} onClick={modal.handleSubmit} disabled={modal.loading}>
                {modal.loading ? '提交中...' : '提交'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* 批量导入模态框 */}
      {showBatchModal && (
        <div className={styles.modalOverlay} onClick={() => setShowBatchModal(false)}>
          <div className={styles.modal} onClick={e => e.stopPropagation()}>
            <h3 className={styles.modalTitle}>批量导入敏感词</h3>
            <div className={styles.formGroup}>
              <label>敏感词列表（每行一个）*</label>
              <textarea className={styles.batchArea} value={batchText} onChange={e => setBatchText(e.target.value)} placeholder={'输入敏感词，每行一个\n例如：\n毒品\n赌博\n诈骗'} />
              <div className={styles.batchHint}>已输入 {batchText.split('\n').filter(w => w.trim()).length} 个词</div>
            </div>
            <div className={styles.formGroup}>
              <label>统一分类</label>
              <select value={batchCategory} onChange={e => setBatchCategory(e.target.value)}>
                {CATEGORIES.map(c => <option key={c.value} value={c.value}>{c.label}</option>)}
              </select>
            </div>
            <div className={styles.formGroup}>
              <label>统一处理方式</label>
              <select value={batchLevel} onChange={e => setBatchLevel(e.target.value as 'mask' | 'review')}>
                <option value="review">人工审核</option>
                <option value="mask">遮蔽替换</option>
              </select>
            </div>
            <div className={styles.modalFooter}>
              <button className={styles.btnCancel} onClick={() => setShowBatchModal(false)}>取消</button>
              <button className={styles.btnSubmit} onClick={handleBatchImport} disabled={batchLoading}>
                {batchLoading ? '导入中...' : '导入'}
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  );
};

// ═══════════════════════════════════════════════════════════════
// Tab 2: 谐音映射
// ═══════════════════════════════════════════════════════════════

const HomophonesTab: React.FC = () => {
  const [keyword, setKeyword] = useState('');

  const fetchMappings = useCallback(async ({ page, pageSize, filters }: any) => {
    const response = await getHomophoneMappings({
      skip: (page - 1) * pageSize,
      limit: pageSize,
      keyword: filters?.keyword,
    });
    return { data: response.items || [], total: response.total || 0 };
  }, []);

  const table = useAdminTable<HomophoneMapping>({
    fetchData: fetchMappings,
    initialPageSize: 20,
    onError: (err) => message.error(getErrorMessage(err)),
  });

  const modal = useModalForm<HomophoneMappingForm>({
    initialValues: initialHomophoneForm,
    onSubmit: async (values) => {
      await createHomophoneMapping(values);
      message.success('创建成功');
      table.refresh();
    },
    onError: (err) => message.error(getErrorMessage(err)),
  });

  const handleDelete = async (mapping: HomophoneMapping) => {
    if (!window.confirm(`确定删除谐音映射"${mapping.variant} → ${mapping.standard}"吗？`)) return;
    try {
      await deleteHomophoneMapping(mapping.id);
      message.success('删除成功');
      table.refresh();
    } catch (err) {
      message.error(getErrorMessage(err));
    }
  };

  const columns: Column<HomophoneMapping>[] = [
    { key: 'id', title: 'ID', dataIndex: 'id', width: 70 },
    { key: 'variant', title: '变体词', dataIndex: 'variant', width: 200 },
    { key: 'standard', title: '标准词', dataIndex: 'standard', width: 200 },
    {
      key: 'is_active',
      title: '状态',
      dataIndex: 'is_active',
      width: 80,
      render: (value) => (
        <span className={`${styles.badge} ${value ? styles.badgeActive : styles.badgeInactive}`}>
          {value ? '启用' : '停用'}
        </span>
      ),
    },
    {
      key: 'actions',
      title: '操作',
      width: 100,
      align: 'center',
      render: (_, record) => (
        <div className={styles.actions}>
          <button className={styles.btnDelete} onClick={() => handleDelete(record)}>删除</button>
        </div>
      ),
    },
  ];

  return (
    <>
      <div className={styles.filters}>
        <div className={styles.filterGroup}>
          <label>搜索：</label>
          <input
            className={styles.input}
            placeholder="搜索变体词或标准词..."
            value={keyword}
            onChange={e => setKeyword(e.target.value)}
            onKeyDown={e => {
              if (e.key === 'Enter') table.setFilters({ keyword: keyword || undefined });
            }}
          />
        </div>
        <button className={styles.btnCreate} onClick={() => table.setFilters({ keyword: keyword || undefined })}>筛选</button>
        <button className={styles.btnCreate} onClick={() => modal.open(initialHomophoneForm, true)}>+ 添加</button>
      </div>

      <AdminTable columns={columns} data={table.data} loading={table.loading} refreshing={table.fetching} rowKey="id" emptyText="暂无谐音映射" />
      <AdminPagination currentPage={table.currentPage} totalPages={table.totalPages} total={table.total} pageSize={table.pageSize} onPageChange={table.setCurrentPage} onPageSizeChange={table.setPageSize} />

      {modal.isOpen && (
        <div className={styles.modalOverlay} onClick={modal.close}>
          <div className={styles.modal} onClick={e => e.stopPropagation()}>
            <h3 className={styles.modalTitle}>添加谐音映射</h3>
            <div className={styles.formGroup}>
              <label>变体词 *（用户可能输入的谐音/变体）</label>
              <input value={modal.formData.variant} onChange={e => modal.setFormData({ ...modal.formData, variant: e.target.value })} placeholder="例如：威信" />
            </div>
            <div className={styles.formGroup}>
              <label>标准词 *（映射到的敏感词库词汇）</label>
              <input value={modal.formData.standard} onChange={e => modal.setFormData({ ...modal.formData, standard: e.target.value })} placeholder="例如：微信" />
            </div>
            <div className={styles.modalFooter}>
              <button className={styles.btnCancel} onClick={modal.close}>取消</button>
              <button className={styles.btnSubmit} onClick={modal.handleSubmit} disabled={modal.loading}>
                {modal.loading ? '提交中...' : '提交'}
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  );
};

// ═══════════════════════════════════════════════════════════════
// Tab 3: 内容审核队列
// ═══════════════════════════════════════════════════════════════

const ReviewsTab: React.FC = () => {
  const [statusFilter, setStatusFilter] = useState('pending');
  const [contentTypeFilter, setContentTypeFilter] = useState('');

  const fetchReviews = useCallback(async ({ page, pageSize, filters }: any) => {
    const response = await getContentReviews({
      skip: (page - 1) * pageSize,
      limit: pageSize,
      status: filters?.status ?? 'pending',
      content_type: filters?.content_type,
    });
    return { data: response.items || [], total: response.total || 0 };
  }, []);

  const table = useAdminTable<ContentReview>({
    fetchData: fetchReviews,
    initialPageSize: 20,
    onError: (err) => message.error(getErrorMessage(err)),
  });

  const handleReview = async (review: ContentReview, action: 'approved' | 'rejected' | 'restored') => {
    const labelMap: Record<string, string> = { approved: '通过', rejected: '拒绝', restored: '恢复原文' };
    const label = labelMap[action] || action;
    if (!window.confirm(`确定${label}此内容吗？`)) return;
    try {
      await reviewContent(review.id, { action });
      message.success(`已${label}`);
      table.refresh();
    } catch (err) {
      message.error(getErrorMessage(err));
    }
  };

  const applyFilters = (overrides?: Record<string, any>) => {
    table.setFilters({
      status: statusFilter || undefined,
      content_type: contentTypeFilter || undefined,
      ...overrides,
    });
  };

  const columns: Column<ContentReview>[] = [
    { key: 'id', title: 'ID', dataIndex: 'id', width: 70 },
    {
      key: 'content_type',
      title: '内容类型',
      dataIndex: 'content_type',
      width: 100,
      render: (value) => CONTENT_TYPE_MAP[value] || value,
    },
    { key: 'user_id', title: '用户ID', dataIndex: 'user_id', width: 100 },
    {
      key: 'original_text',
      title: '原始内容',
      dataIndex: 'original_text',
      width: 300,
      render: (value) => <div className={styles.originalText} title={value}>{value}</div>,
    },
    {
      key: 'matched_words',
      title: '命中敏感词',
      width: 200,
      render: (_, record) => (
        <div className={styles.matchedWords}>
          {record.matched_words?.map((m, i) => (
            <span key={i} className={styles.matchedWord}>{m.word}</span>
          ))}
        </div>
      ),
    },
    {
      key: 'status',
      title: '状态',
      dataIndex: 'status',
      width: 100,
      render: (value) => {
        const map: Record<string, { text: string; variant: any }> = {
          pending: { text: '待审核', variant: 'warning' },
          approved: { text: '已通过', variant: 'success' },
          rejected: { text: '已拒绝', variant: 'danger' },
          masked: { text: '已屏蔽', variant: 'info' },
          restored: { text: '已恢复', variant: 'success' },
        };
        const cfg = map[value] || { text: value, variant: 'default' };
        return <StatusBadge text={cfg.text} variant={cfg.variant} />;
      },
    },
    {
      key: 'created_at',
      title: '提交时间',
      dataIndex: 'created_at',
      width: 160,
      render: (value) => new Date(value).toLocaleString('zh-CN'),
    },
    {
      key: 'actions',
      title: '操作',
      width: 150,
      align: 'center',
      render: (_, record) => {
        if (record.status === 'pending') {
          return (
            <div className={styles.actions}>
              <button className={styles.btnApprove} onClick={() => handleReview(record, 'approved')}>通过</button>
              <button className={styles.btnReject} onClick={() => handleReview(record, 'rejected')}>拒绝</button>
            </div>
          );
        }
        if (record.status === 'masked') {
          return (
            <div className={styles.actions}>
              <button className={styles.btnApprove} onClick={() => handleReview(record, 'restored')}>恢复原文</button>
            </div>
          );
        }
        return (
          <span style={{ color: '#6c757d', fontSize: 13 }}>
            {record.reviewed_by ? `由 ${record.reviewed_by} 处理` : '-'}
          </span>
        );
      },
    },
  ];

  return (
    <>
      <div className={styles.filters}>
        <div className={styles.filterGroup}>
          <label>状态：</label>
          <select className={styles.select} value={statusFilter} onChange={e => { setStatusFilter(e.target.value); applyFilters({ status: e.target.value || undefined }); }}>
            <option value="">全部</option>
            <option value="pending">待审核</option>
            <option value="approved">已通过</option>
            <option value="rejected">已拒绝</option>
            <option value="masked">已屏蔽</option>
            <option value="restored">已恢复</option>
          </select>
        </div>
        <div className={styles.filterGroup}>
          <label>内容类型：</label>
          <select className={styles.select} value={contentTypeFilter} onChange={e => { setContentTypeFilter(e.target.value); applyFilters({ content_type: e.target.value || undefined }); }}>
            <option value="">全部</option>
            {Object.entries(CONTENT_TYPE_MAP).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
          </select>
        </div>
      </div>

      <AdminTable columns={columns} data={table.data} loading={table.loading} refreshing={table.fetching} rowKey="id" emptyText="暂无待审核内容" />
      <AdminPagination currentPage={table.currentPage} totalPages={table.totalPages} total={table.total} pageSize={table.pageSize} onPageChange={table.setCurrentPage} onPageSizeChange={table.setPageSize} />
    </>
  );
};

// ═══════════════════════════════════════════════════════════════
// Tab 4: 过滤日志
// ═══════════════════════════════════════════════════════════════

const LogsTab: React.FC = () => {
  const [actionFilter, setActionFilter] = useState('');
  const [contentTypeFilter, setContentTypeFilter] = useState('');

  const fetchLogs = useCallback(async ({ page, pageSize, filters }: any) => {
    const response = await getFilterLogs({
      skip: (page - 1) * pageSize,
      limit: pageSize,
      action: filters?.action,
      content_type: filters?.content_type,
    });
    return { data: response.items || [], total: response.total || 0 };
  }, []);

  const table = useAdminTable<FilterLog>({
    fetchData: fetchLogs,
    initialPageSize: 20,
    onError: (err) => message.error(getErrorMessage(err)),
  });

  const applyFilters = (overrides?: Record<string, any>) => {
    table.setFilters({
      action: actionFilter || undefined,
      content_type: contentTypeFilter || undefined,
      ...overrides,
    });
  };

  const columns: Column<FilterLog>[] = [
    { key: 'id', title: 'ID', dataIndex: 'id', width: 70 },
    { key: 'user_id', title: '用户ID', dataIndex: 'user_id', width: 100 },
    {
      key: 'content_type',
      title: '内容类型',
      dataIndex: 'content_type',
      width: 100,
      render: (value) => CONTENT_TYPE_MAP[value] || value,
    },
    {
      key: 'action',
      title: '处理结果',
      dataIndex: 'action',
      width: 100,
      render: (value) => {
        const variant = value === 'pass' ? 'success' : value === 'mask' ? 'warning' : 'danger';
        return <StatusBadge text={ACTION_MAP[value] || value} variant={variant} />;
      },
    },
    {
      key: 'matched_words',
      title: '命中敏感词',
      width: 250,
      render: (_, record) => (
        <div className={styles.matchedWords}>
          {record.matched_words?.map((m, i) => (
            <span key={i} className={styles.matchedWord}>{m.word}</span>
          ))}
        </div>
      ),
    },
    {
      key: 'created_at',
      title: '时间',
      dataIndex: 'created_at',
      width: 160,
      render: (value) => new Date(value).toLocaleString('zh-CN'),
    },
  ];

  return (
    <>
      <div className={styles.filters}>
        <div className={styles.filterGroup}>
          <label>处理结果：</label>
          <select className={styles.select} value={actionFilter} onChange={e => { setActionFilter(e.target.value); applyFilters({ action: e.target.value || undefined }); }}>
            <option value="">全部</option>
            <option value="review">审核</option>
            <option value="mask">遮蔽</option>
            <option value="pass">通过</option>
          </select>
        </div>
        <div className={styles.filterGroup}>
          <label>内容类型：</label>
          <select className={styles.select} value={contentTypeFilter} onChange={e => { setContentTypeFilter(e.target.value); applyFilters({ content_type: e.target.value || undefined }); }}>
            <option value="">全部</option>
            {Object.entries(CONTENT_TYPE_MAP).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
          </select>
        </div>
      </div>

      <AdminTable columns={columns} data={table.data} loading={table.loading} refreshing={table.fetching} rowKey="id" emptyText="暂无过滤日志" />
      <AdminPagination currentPage={table.currentPage} totalPages={table.totalPages} total={table.total} pageSize={table.pageSize} onPageChange={table.setCurrentPage} onPageSizeChange={table.setPageSize} />
    </>
  );
};

export default ContentModerationPage;
