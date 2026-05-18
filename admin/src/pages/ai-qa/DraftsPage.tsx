// admin/src/pages/ai-qa/DraftsPage.tsx
// AI 限时问答 草稿管理页 (A3)
// 路径: /admin/ai-qa/drafts
import React, { useEffect, useState } from 'react';
import { aiQaApi, Draft } from '../../api/aiQa';
import { FloorPenceInput } from '../../components/ai-qa/FloorPenceInput';

// deadline 默认 7 天后, datetime-local 输入需要本地格式 (YYYY-MM-DDTHH:mm 无 timezone)
// — submit 时通过 toLocalISOString 转 UTC ISO 给后端,避免 timezone 错位 (deep audit issue #4)
const sevenDaysLater = () => {
  const d = new Date(Date.now() + 7 * 86400000);
  // 本地年月日时分,用 datetime-local 显示
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
};

const EMPTY_DRAFT: Draft = {
  title: '',
  content: '',
  target_forum_category_id: 1, // 默认 1, FK 必须存在 (deep audit issue #5); admin 应改成实际板块 id
  deadline: sevenDaysLater(),
  reward_pool_pence: 1000,
  participation_points: 5,
  floor_pence: 10,
  edit_lock_hours_before: 1,
};

// datetime-local input 输出 'YYYY-MM-DDTHH:mm' 是本地时间,提交时转 UTC ISO
const localToUTCISO = (local: string): string => {
  if (!local) return local;
  // local 已是 'YYYY-MM-DDTHH:mm', Date 构造默认按本地时区解释
  const d = new Date(local);
  return d.toISOString(); // 'YYYY-MM-DDTHH:mm:ss.sssZ'
};

export const DraftsPage: React.FC = () => {
  const [drafts, setDrafts] = useState<any[]>([]);
  const [editing, setEditing] = useState<Draft | null>(null);
  const [confirmHigh, setConfirmHigh] = useState(false);

  const reload = () => aiQaApi.listDrafts().then(setDrafts);
  useEffect(() => {
    reload();
  }, []);

  const handleSave = async () => {
    if (!editing) return;
    if (editing.reward_pool_pence > 5000 && !confirmHigh) {
      alert('大额奖金池(>£50)请勾选下方确认');
      return;
    }
    if (!editing.target_forum_category_id || editing.target_forum_category_id <= 0) {
      alert('请填写有效的目标论坛板块 id (必须 > 0)');
      return;
    }
    // deadline 从 datetime-local (本地时间) 转 UTC ISO 给后端
    const payload = { ...editing, deadline: localToUTCISO(editing.deadline) };
    if (editing.id) {
      await aiQaApi.updateDraft(editing.id, payload);
    } else {
      await aiQaApi.createDraft(payload);
    }
    setEditing(null);
    setConfirmHigh(false);
    reload();
  };

  const handlePublish = async (id: number) => {
    if (!window.confirm('确认发布到 published?')) return;
    await aiQaApi.publishDraft(id);
    reload();
  };

  const handleDelete = async (id: number) => {
    if (!window.confirm('确认删除草稿?')) return;
    await aiQaApi.deleteDraft(id);
    reload();
  };

  return (
    <div>
      <h2>草稿管理</h2>
      <button onClick={() => setEditing({ ...EMPTY_DRAFT })}>+ 新建草稿</button>

      <table style={{ marginTop: 16, width: '100%', borderCollapse: 'collapse' }}>
        <thead>
          <tr>
            <th>ID</th>
            <th>题面</th>
            <th>板块</th>
            <th>奖金池</th>
            <th>截止</th>
            <th>操作</th>
          </tr>
        </thead>
        <tbody>
          {drafts.map(d => (
            <tr key={d.id}>
              <td>#{d.id}</td>
              <td>{d.title}</td>
              <td>{d.target_forum_category_id}</td>
              <td>£{(d.reward_pool_pence / 100).toFixed(2)}</td>
              <td>{new Date(d.deadline).toLocaleString()}</td>
              <td>
                <button onClick={() => handlePublish(d.id)}>发布</button>
                <button onClick={() => setEditing(d)}>编辑</button>
                <button onClick={() => handleDelete(d.id)}>删除</button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>

      {editing && (
        <div style={{ marginTop: 24, padding: 20, background: '#fff', borderRadius: 8 }}>
          <h3>{editing.id ? `编辑草稿 #${editing.id}` : '新建草稿'}</h3>
          <label>
            题面
            <input
              value={editing.title}
              onChange={e => setEditing({ ...editing, title: e.target.value })}
            />
          </label>
          <label>
            正文
            <textarea
              value={editing.content}
              onChange={e => setEditing({ ...editing, content: e.target.value })}
            />
          </label>
          <label>
            目标论坛板块 id
            <input
              type="number"
              value={editing.target_forum_category_id}
              onChange={e =>
                setEditing({ ...editing, target_forum_category_id: parseInt(e.target.value, 10) })
              }
            />
          </label>
          <label>
            截止时间
            <input
              type="datetime-local"
              value={editing.deadline}
              onChange={e => setEditing({ ...editing, deadline: e.target.value })}
            />
          </label>
          <label>
            奖金池 pence (上限 100000)
            <input
              type="number"
              min={0}
              max={100000}
              value={editing.reward_pool_pence}
              onChange={e =>
                setEditing({ ...editing, reward_pool_pence: parseInt(e.target.value, 10) })
              }
            />
          </label>
          {editing.reward_pool_pence > 5000 && (
            <label style={{ color: 'red' }}>
              <input
                type="checkbox"
                checked={confirmHigh}
                onChange={e => setConfirmHigh(e.target.checked)}
              />
              我已确认 £{(editing.reward_pool_pence / 100).toFixed(2)} 大额奖金池
            </label>
          )}
          <FloorPenceInput
            value={editing.floor_pence}
            onChange={fp => setEditing({ ...editing, floor_pence: fp })}
            poolPence={editing.reward_pool_pence}
          />
          <div style={{ marginTop: 16 }}>
            <button onClick={handleSave}>保存草稿</button>
            <button
              onClick={() => {
                setEditing(null);
                setConfirmHigh(false);
              }}
            >
              取消
            </button>
          </div>
        </div>
      )}
    </div>
  );
};

export default DraftsPage;
