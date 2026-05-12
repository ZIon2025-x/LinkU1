import React from 'react';

export const TabBtn = React.memo(function TabBtn({ active, onClick, children }) {
  return (
    <button onClick={onClick}
      className={`py-2 border transition-all ${active ? 'border-current bg-current/10' : 'border-current/30 opacity-60 hover:opacity-100'}`}>
      {children}
    </button>
  );
});

const _miniStatLabelStyle = { fontFamily: 'monospace' };
export const MiniStat = React.memo(function MiniStat({ label, value, unit, valueColor }) {
  const isHigh = !!valueColor;
  const labelStyle = { ..._miniStatLabelStyle, color: valueColor };
  return (
    <div className="border px-1.5 py-1.5 text-center"
      style={{ borderColor: isHigh ? valueColor + '60' : undefined, background: isHigh ? valueColor + '0a' : undefined }}>
      <div className="opacity-60 text-[10px]" style={labelStyle}>{label}</div>
      <div className="text-[11px] mt-0.5 leading-tight" style={labelStyle}>{value}{unit}</div>
    </div>
  );
});

// ── Link2Ur 创业线 v2 atoms ──

export function InboxCard({ task, onAccept, onDecline, onAssign, hasTeam }) {
  const daysLeft = (task.dueByDay || 0) - (task.currentDay || 0);
  const urgent = daysLeft <= 2;
  return (
    <div className={`bg-white rounded-lg p-4 shadow-sm border ${urgent ? 'border-orange-400' : 'border-gray-200'}`}>
      <div className="flex justify-between items-start mb-2">
        <div>
          <span className="text-2xl mr-2">{task.emoji}</span>
          <span className="font-semibold">{task.title}</span>
        </div>
        <span className="text-sm text-orange-600 font-medium">
          £{task.reward} {task.rewardBonus ? `(+${Math.round(task.rewardBonus * 100)}% VIP)` : ''}
        </span>
      </div>
      <p className="text-sm text-gray-600 mb-2">{task.desc}</p>
      <div className="flex items-center gap-3 text-xs text-gray-500 mb-3">
        <span>⏰ {daysLeft} 天后过期</span>
        <span>📅 必须 {task.mustCompleteByDay - task.currentDay} 天内完成</span>
        <span>⚡ -{task.energyCost}</span>
      </div>
      <div className="flex gap-2">
        <button onClick={onAccept} className="flex-1 bg-blue-600 text-white py-2 rounded font-medium hover:bg-blue-700">接受</button>
        {hasTeam && <button onClick={onAssign} className="flex-1 bg-purple-600 text-white py-2 rounded font-medium hover:bg-purple-700">分给团员</button>}
        <button onClick={onDecline} className="flex-1 bg-gray-200 text-gray-700 py-2 rounded font-medium hover:bg-gray-300">拒绝</button>
      </div>
    </div>
  );
}

export function PhaseIndicator({ phase, daysUntilShift }) {
  if (phase === 1) {
    return (
      <div className="bg-green-50 text-green-800 text-sm rounded px-3 py-2 flex items-center gap-2">
        🌱 <span className="font-medium">Phase 1 · 留学生 AI 服务</span>
        {daysUntilShift && <span className="text-xs ml-auto opacity-75">距离转型 {daysUntilShift} 天</span>}
      </div>
    );
  }
  return (
    <div className="bg-blue-50 text-blue-800 text-sm rounded px-3 py-2 flex items-center gap-2">
      🚀 <span className="font-medium">Phase 2 · 跨境 AI Studio</span>
    </div>
  );
}
