import React, { useState, useCallback, useEffect } from 'react';
import { message, Modal, Button } from 'antd';
import { getStuckTaskPayouts, recoverStuckTaskPayout, StuckTaskPayout } from '../../../api';
import { getErrorMessage } from '../../../utils/errorHandler';

/**
 * 卡死任务 payout 恢复管理。
 *
 * 场景: confirm_task_completion 在 payout 时抛异常 (历史上的
 * UnboundLocalError on stripe 等), 外层 task.status="completed" +
 * confirmed_at 已经在 try 之前 commit,但 payout savepoint rollback
 * 让 escrow/is_confirmed/paid_to_user_id 留在 zombie 态,自动调度器
 * (auto_transfer_expired_tasks 要 confirmed_at IS NULL) 永远拿不到。
 *
 * 这个面板列出所有这类卡住的任务,点"恢复"即通过 credit_wallet 把
 * escrow 入到 taker 本地钱包,清 escrow + 标 is_confirmed=1。
 * 幂等键 earning:task:X:user:Y 与 confirm 路径一致,重复点不会重复加钱。
 */
const StuckPayoutsManagement: React.FC = () => {
  const [list, setList] = useState<StuckTaskPayout[]>([]);
  const [loading, setLoading] = useState(false);
  const [recovering, setRecovering] = useState<Record<number, boolean>>({});

  const loadList = useCallback(async () => {
    setLoading(true);
    try {
      const res = await getStuckTaskPayouts();
      setList(res);
    } catch (e) {
      message.error(getErrorMessage(e));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadList();
  }, [loadList]);

  const handleRecover = (row: StuckTaskPayout) => {
    Modal.confirm({
      title: `恢复任务 #${row.task_id} 的 payout?`,
      content: (
        <div>
          <p style={{ marginBottom: 8 }}>
            将通过 credit_wallet 把 escrow 余额 <b>£{row.escrow_amount}</b> 入到
            taker (<code>{row.taker_id}</code>) 本地钱包, 并标记
            <code> is_confirmed = 1 </code>。
          </p>
          <p style={{ color: '#888', fontSize: 12 }}>
            幂等键和 confirm 路径一致,重复点不会重复加钱。
          </p>
        </div>
      ),
      okText: '确定恢复',
      cancelText: '取消',
      onOk: async () => {
        setRecovering((s) => ({ ...s, [row.task_id]: true }));
        try {
          const res = await recoverStuckTaskPayout(row.task_id);
          message.success(`✅ 任务 ${row.task_id} 已恢复, 已补 £${res?.amount ?? row.escrow_amount} 到 ${row.taker_id}`);
          loadList();
        } catch (e) {
          message.error(getErrorMessage(e));
        } finally {
          setRecovering((s) => ({ ...s, [row.task_id]: false }));
        }
      },
    });
  };

  return (
    <div>
      <h2 style={{ marginBottom: 12 }}>卡死任务 payout 恢复</h2>
      <p style={{ color: '#666', marginBottom: 16, fontSize: 13, lineHeight: 1.6 }}>
        列出 <code>status=completed</code> + <code>is_confirmed=0</code> +{' '}
        <code>escrow&gt;0</code> + <code>paid_to_user_id=NULL</code> 的任务 ——
        confirm_task_completion 中途异常留下的 zombie。auto_transfer_expired_tasks
        调度器看不到这些 (它要求 <code>confirmed_at IS NULL</code>), 必须人工触发恢复。
      </p>

      <div style={{ marginBottom: 12 }}>
        <Button onClick={loadList} loading={loading}>刷新</Button>
        <span style={{ marginLeft: 16, color: '#888' }}>
          共 {list.length} 个待恢复任务
        </span>
      </div>

      <div style={{ overflowX: 'auto' }}>
        <table
          style={{
            width: '100%',
            borderCollapse: 'collapse',
            background: 'white',
            boxShadow: '0 2px 4px rgba(0,0,0,0.08)',
            borderRadius: 8,
          }}
        >
          <thead>
            <tr style={{ borderBottom: '1px solid #eee' }}>
              <th style={{ padding: 12, textAlign: 'left', width: 80 }}>Task ID</th>
              <th style={{ padding: 12, textAlign: 'left' }}>标题</th>
              <th style={{ padding: 12, textAlign: 'left', width: 100 }}>Taker</th>
              <th style={{ padding: 12, textAlign: 'left', width: 100 }}>金额</th>
              <th style={{ padding: 12, textAlign: 'left', width: 170 }}>Confirmed at</th>
              <th style={{ padding: 12, textAlign: 'left', width: 120 }}>操作</th>
            </tr>
          </thead>
          <tbody>
            {loading && (
              <tr>
                <td colSpan={6} style={{ padding: 24, textAlign: 'center', color: '#999' }}>
                  加载中...
                </td>
              </tr>
            )}
            {!loading && list.length === 0 && (
              <tr>
                <td colSpan={6} style={{ padding: 24, textAlign: 'center', color: '#999' }}>
                  没有卡死的任务,一切正常 ✅
                </td>
              </tr>
            )}
            {!loading &&
              list.map((row) => (
                <tr key={row.task_id} style={{ borderBottom: '1px solid #f0f0f0' }}>
                  <td style={{ padding: 12, fontFamily: 'monospace' }}>{row.task_id}</td>
                  <td style={{ padding: 12 }}>{row.title}</td>
                  <td style={{ padding: 12, fontFamily: 'monospace' }}>{row.taker_id}</td>
                  <td style={{ padding: 12 }}>
                    {row.currency} £{row.escrow_amount}
                  </td>
                  <td style={{ padding: 12, fontSize: 12, color: '#666' }}>
                    {row.confirmed_at
                      ? new Date(row.confirmed_at).toLocaleString('zh-CN')
                      : '-'}
                  </td>
                  <td style={{ padding: 12 }}>
                    <Button
                      type="primary"
                      size="small"
                      loading={!!recovering[row.task_id]}
                      onClick={() => handleRecover(row)}
                    >
                      恢复
                    </Button>
                  </td>
                </tr>
              ))}
          </tbody>
        </table>
      </div>
    </div>
  );
};

export default StuckPayoutsManagement;
