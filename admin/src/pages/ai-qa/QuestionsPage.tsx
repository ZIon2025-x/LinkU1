// admin/src/pages/ai-qa/QuestionsPage.tsx
// AI 限时问答 题目列表页 (A4)
// 路径: /admin/ai-qa/questions
import React, { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { aiQaApi } from "../../api/aiQa";

const STATUS_LABELS: Record<string, { label: string; color: string }> = {
  draft: { label: "draft", color: "#6b7280" },
  published: { label: "published", color: "#1e40af" },
  canceled: { label: "canceled", color: "#991b1b" },
  closed: { label: "closed", color: "#4338ca" },
  closed_empty: { label: "closed_empty", color: "#6b7280" },
  scoring: { label: "scoring", color: "#92400e" },
  scoring_failed: { label: "scoring_failed", color: "#7f1d1d" },
  scored: { label: "scored", color: "#5b21b6" },
  settled: { label: "settled", color: "#065f46" },
  settle_failed: { label: "settle_failed", color: "#7f1d1d" },
};

export const QuestionsPage: React.FC = () => {
  const [questions, setQuestions] = useState<any[]>([]);
  const [filter, setFilter] = useState<string>("");

  useEffect(() => {
    aiQaApi.listQuestions(filter || undefined).then(setQuestions);
  }, [filter]);

  const handleCancel = async (id: number) => {
    const reason = prompt("撤稿原因？");
    if (!reason) return;
    await aiQaApi.cancelQuestion(id, reason);
    aiQaApi.listQuestions(filter || undefined).then(setQuestions);
  };

  return (
    <div>
      <h2>题目列表</h2>
      <label>
        状态：
        <select value={filter} onChange={e => setFilter(e.target.value)}>
          <option value="">全部</option>
          {Object.keys(STATUS_LABELS).map(s => <option key={s} value={s}>{s}</option>)}
        </select>
      </label>

      <table style={{ marginTop: 16, width: "100%", borderCollapse: "collapse" }}>
        <thead>
          <tr><th>ID</th><th>题面</th><th>状态</th><th>奖金池</th><th>截止</th><th>操作</th></tr>
        </thead>
        <tbody>
          {questions.map(q => {
            const st = STATUS_LABELS[q.status] || { label: q.status, color: "#000" };
            return (
              <tr key={q.id}>
                <td>#{q.id}</td>
                <td>{q.title}</td>
                <td><span style={{ background: st.color + "22", color: st.color, padding: "2px 8px", borderRadius: 99 }}>{st.label}</span></td>
                <td>£{(q.reward_pool_pence / 100).toFixed(2)}</td>
                <td>{q.deadline ? new Date(q.deadline).toLocaleString() : "—"}</td>
                <td>
                  {(q.status === "scored" || q.status === "settle_failed") && (
                    <Link to={`/admin/ai-qa/review/${q.id}`}>→ 终审</Link>
                  )}
                  {q.status === "published" && (
                    <button onClick={() => handleCancel(q.id)}>撤稿</button>
                  )}
                  {q.status === "scoring_failed" && (
                    <button onClick={() => aiQaApi.rescore(q.id).then(() => aiQaApi.listQuestions(filter || undefined).then(setQuestions))}>重跑评分</button>
                  )}
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
};

export default QuestionsPage;
