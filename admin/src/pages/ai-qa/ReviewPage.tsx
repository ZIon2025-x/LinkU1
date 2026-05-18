// admin/src/pages/ai-qa/ReviewPage.tsx
import React, { useEffect, useState, useMemo } from "react";
import { useParams } from "react-router-dom";
import { aiQaApi } from "../../api/aiQa";

export const ReviewPage: React.FC = () => {
  const { qid } = useParams<{ qid: string }>();
  const [data, setData] = useState<any>(null);
  const [rows, setRows] = useState<any[]>([]);
  const [sortBy, setSortBy] = useState<"risk" | "created" | "ai_score">("risk");

  const reload = () => {
    if (qid) aiQaApi.getReview(parseInt(qid)).then(d => {
      setData(d);
      setRows(d.rows);
    });
  };
  useEffect(() => { reload(); }, [qid]);

  const totalBudget = useMemo(() => {
    // 新算法：全员按比例分,floor_pence 抹零;预算估算 = 池子全发完
    if (!data) return 0;
    const activeRows = rows.filter(r => !r.hide_in_qa);
    const scores = activeRows.map(r => r.admin_override_score ?? r.ai_score ?? 0);
    const total = scores.reduce((a, b) => a + b, 0);
    if (total === 0) return 0;
    return data.question.reward_pool_pence;  // 全发完 (无 winners_count cap)
  }, [data, rows]);

  if (!data) return <div>Loading...</div>;

  const sorted = [...rows].sort((a, b) => {
    if (sortBy === "risk") return b.risk_score - a.risk_score;
    if (sortBy === "created") return new Date(a.forum_post_created_at).getTime() - new Date(b.forum_post_created_at).getTime();
    return (b.ai_score ?? 0) - (a.ai_score ?? 0);
  });

  const handleScoreChange = (id: number, score: number) => {
    setRows(rows.map(r => r.id === id ? { ...r, admin_override_score: score } : r));
    aiQaApi.updateScore(id, { admin_override_score: score });
  };

  const handleHideChange = (id: number, hide: boolean) => {
    setRows(rows.map(r => r.id === id ? { ...r, hide_in_qa: hide } : r));
    aiQaApi.updateScore(id, { hide_in_qa: hide });
  };

  const handleSettle = async () => {
    if (!confirm(`确认发放 £${(data.question.reward_pool_pence / 100).toFixed(2)} 奖金给 ${rows.filter(r => !r.hide_in_qa).length} 位答主？不可撤回`)) return;
    try {
      const result = await aiQaApi.settle(parseInt(qid!));
      alert(`✅ 已发奖：£${(result.total_settled_pence / 100).toFixed(2)} 给 ${result.winner_count} 人`);
      reload();
    } catch (e: any) {
      alert(`❌ 发奖失败：${e.response?.data?.detail || e.message}`);
      reload();
    }
  };

  return (
    <div>
      <h2>{data.question.title} · 终审</h2>
      <div style={{ display: "flex", gap: 24, background: "#fef3c7", padding: 12, borderRadius: 8, marginBottom: 16 }}>
        <div>奖金池: <strong>£{(data.question.reward_pool_pence / 100).toFixed(2)}</strong></div>
        <div>分配预算: <strong>£{(totalBudget / 100).toFixed(2)}</strong></div>
        <div>本周已 settled: <strong>£{(data.weekly_settled_pence / 100).toFixed(2)}</strong> / 上限 £{(data.weekly_cap_pence / 100).toFixed(2)}</div>
        <button onClick={() => aiQaApi.rescore(parseInt(qid!)).then(reload)}>重跑 AI 评分</button>
        <button onClick={handleSettle} style={{ background: "#10b981", color: "white" }}>✓ 确认发奖</button>
      </div>

      <div>
        排序：
        <button onClick={() => setSortBy("risk")}>风险降序</button>
        <button onClick={() => setSortBy("created")}>发布时间升序</button>
        <button onClick={() => setSortBy("ai_score")}>AI 分降序</button>
      </div>

      <table style={{ marginTop: 12, width: "100%", borderCollapse: "collapse" }}>
        <thead>
          <tr>
            <th>#</th><th>用户</th><th>发布时间</th><th>答案预览</th>
            <th>AI 分</th><th>AI 检测</th><th>风险</th>
            <th>改分</th><th>屏蔽</th>
          </tr>
        </thead>
        <tbody>
          {sorted.map((r, idx) => {
            const isEdited = r.is_edited;
            const isHighRisk = r.risk_score >= 30;
            return (
              <tr key={r.id} style={{ background: isHighRisk ? "#fff5f5" : undefined }}>
                <td>{idx + 1}</td>
                <td>{r.user_name || r.user_id}</td>
                <td>
                  {new Date(r.forum_post_created_at).toLocaleString()}<br />
                  {isEdited && <small style={{ color: "#dc2626" }}>⚠ 已编辑</small>}
                </td>
                <td style={{ maxWidth: 280, overflow: "hidden", textOverflow: "ellipsis" }}>{r.content_preview}</td>
                <td>{r.ai_score ?? "—"}</td>
                <td><span style={{ background: r.ai_generated === "high" ? "#fee2e2" : r.ai_generated === "medium" ? "#fef3c7" : "#d1fae5", padding: "1px 6px", borderRadius: 4, fontSize: 10 }}>{r.ai_generated ?? "—"}</span></td>
                <td>{r.risk_score} {r.risk_reasons && <small>({r.risk_reasons})</small>}</td>
                <td>
                  <input type="number" min={0} max={100}
                         value={r.admin_override_score ?? r.ai_score ?? 0}
                         onChange={e => handleScoreChange(r.id, parseInt(e.target.value))}
                         style={{ width: 56 }} />
                </td>
                <td>
                  <input type="checkbox" checked={r.hide_in_qa}
                         onChange={e => handleHideChange(r.id, e.target.checked)} />
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
};
