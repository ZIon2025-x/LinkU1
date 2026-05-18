// admin/src/api/aiQa.ts
// AI 限时问答 — Admin 端 API client
//
// 算法已重写 (spec §2.1) — 不再有 TopnFormula 概念,只保留 floor_pence 单字段
// 对应后端: app/ai_qa_admin_routes.py (prefix=/api/admin/ai-qa)

import api from '../api'; // 复用现有 axios 实例 (含 CSRF 拦截、401 自动刷新)

export interface Draft {
  id?: number;
  title: string;
  content: string;
  topic_tag?: string;
  target_forum_category_id: number;
  deadline: string; // ISO 8601, 也接受 datetime-local 字符串
  reward_pool_pence: number;
  participation_points: number;
  floor_pence: number; // 默认 10, 范围 1-1000 pence
  edit_lock_hours_before: number;
  posed_by_expert_id?: string;
}

export const aiQaApi = {
  listDrafts: () =>
    api.get('/api/admin/ai-qa/questions', { params: { status: 'draft' } }).then(r => r.data),
  createDraft: (data: Draft) =>
    api.post('/api/admin/ai-qa/drafts', data).then(r => r.data),
  updateDraft: (id: number, data: Partial<Draft>) =>
    api.patch(`/api/admin/ai-qa/drafts/${id}`, data).then(r => r.data),
  deleteDraft: (id: number) =>
    api.delete(`/api/admin/ai-qa/drafts/${id}`),
  publishDraft: (id: number) =>
    api.post(`/api/admin/ai-qa/drafts/${id}/publish`).then(r => r.data),
  listQuestions: (status?: string) =>
    api.get('/api/admin/ai-qa/questions', { params: { status } }).then(r => r.data),
  cancelQuestion: (id: number, reason: string) =>
    api.post(`/api/admin/ai-qa/questions/${id}/cancel`, { reason }).then(r => r.data),
  getReview: (id: number) =>
    api.get(`/api/admin/ai-qa/questions/${id}/review`).then(r => r.data),
  updateScore: (scoreId: number, data: { admin_override_score?: number; hide_in_qa?: boolean }) =>
    api.patch(`/api/admin/ai-qa/scores/${scoreId}`, data).then(r => r.data),
  rescore: (id: number) =>
    api.post(`/api/admin/ai-qa/questions/${id}/rescore`).then(r => r.data),
  settle: (id: number) =>
    api.post(`/api/admin/ai-qa/questions/${id}/settle`).then(r => r.data),
};
