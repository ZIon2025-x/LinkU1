// admin/src/components/ai-qa/FloorPenceInput.tsx
// 单字段算法 (spec §2.1):
//   所有答主按 final_score 比例分池,低于 floor_pence 的抹零,钱留池子不发
//   floor_pence 默认 10 = £0.10, 范围 1-1000 pence
import React from 'react';

interface Props {
  value: number; // floor_pence, 1-1000
  onChange: (next: number) => void;
  poolPence: number; // 用于实时预览
}

/** 模拟后端 distribute_pool 算法,生成给定答题人数下的预览 */
function preview(floorPence: number, poolPence: number, scores: number[]): string {
  if (scores.length === 0) return '—';
  const total = scores.reduce((a, b) => a + b, 0);
  if (total === 0) return `${scores.length} 人全 0 分 → 每人 £0`;
  const raw = scores.map(s => Math.round((poolPence * s) / total));
  const cleaned = raw.map(amt => (amt >= floorPence ? amt : 0));
  const nonZero = cleaned.filter(amt => amt > 0).length;
  const minAmt = nonZero > 0 ? Math.min(...cleaned.filter(amt => amt > 0)) : 0;
  const maxAmt = Math.max(...cleaned);
  return `${scores.length} 人 → ${nonZero} 人分到 £${(minAmt / 100).toFixed(2)}-£${(maxAmt / 100).toFixed(2)}`;
}

export const FloorPenceInput: React.FC<Props> = ({ value, onChange, poolPence }) => {
  return (
    <div style={{ background: '#f9fafb', border: '1px solid #e5e7eb', padding: 14, borderRadius: 6 }}>
      <label style={{ display: 'block', maxWidth: 320 }}>
        单人最低金额 <code>floor_pence</code> (1-1000)
        <input
          type="number"
          min={1}
          max={1000}
          value={value}
          onChange={e => onChange(parseInt(e.target.value, 10) || 10)}
          style={{ width: '100%', marginTop: 4, padding: 6 }}
        />
        <div style={{ fontSize: 11, color: '#9ca3af', marginTop: 4 }}>
          默认 10 = £0.10。所有答主按 final_score 比例分,低于此值抹零(钱留池子不发)。
        </div>
      </label>

      <div style={{ marginTop: 10, padding: 8, background: '#fff', borderRadius: 4, fontSize: 12, lineHeight: 1.6 }}>
        <strong>实时预览</strong>(按 £{(poolPence / 100).toFixed(2)} 池子 + floor £{(value / 100).toFixed(2)}):<br />
        · {preview(value, poolPence, [90, 80, 70, 60, 50])}(5 人均匀分数)<br />
        · {preview(value, poolPence, Array.from({ length: 30 }, (_, i) => 80 - i))}(30 人均匀)<br />
        · {preview(value, poolPence, [100, ...Array(99).fill(5)])}(100 人,top 1 一枝独秀)<br />
        <span style={{ color: '#6b7280', fontSize: 11 }}>池子越大 → 能高于 floor 的人越多。</span>
      </div>
    </div>
  );
};

export default FloorPenceInput;
