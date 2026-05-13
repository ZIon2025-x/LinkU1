import React from 'react';
import { NPC_IMAGES } from '../engine/imageRegistry.js';

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

export function TeamMemberRow({ member, onMessage }) {
  const energyPct = Math.min(100, member.energy);
  const energyBar = (
    <div className="w-12 h-1.5 bg-gray-200 rounded">
      <div className="h-1.5 bg-green-500 rounded" style={{ width: `${energyPct}%` }} />
    </div>
  );
  return (
    <div className="flex items-center gap-3 py-2 border-b last:border-0">
      {member.avatarImage && NPC_IMAGES[member.avatarImage] ? (
        <img src={NPC_IMAGES[member.avatarImage]} alt="" className="w-8 h-8 rounded-full object-cover" />
      ) : (
        <span className="text-2xl">{member.avatar}</span>
      )}
      <div className="flex-1 min-w-0">
        <div className="text-sm font-medium truncate">{member.name}</div>
        <div className="text-xs text-gray-500 truncate">{member.specialtyDisplay}</div>
      </div>
      <span className="text-xs text-gray-600">⭐ {member.rating}</span>
      {energyBar}
      <button onClick={() => onMessage?.(member.id)} className="text-xs text-blue-600 hover:underline">聊</button>
    </div>
  );
}

export function ClashWarningModal({ taskA, taskB, hasTeam, onResolve, onClose }) {
  if (!taskA || !taskB) return null;
  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
      <div className="bg-white rounded-lg max-w-md w-full p-6 m-4">
        <h3 className="text-lg font-bold mb-2">⚠️ 时间撞档了</h3>
        <p className="text-sm text-gray-700 mb-3">两个指定任务的时间窗口重叠了。你只能选一种处理方式。</p>
        <div className="space-y-2 mb-4 text-xs">
          <div className="bg-orange-50 px-3 py-2 rounded">
            <span className="font-medium">A.</span> {taskA.title} · £{taskA.reward}
          </div>
          <div className="bg-orange-50 px-3 py-2 rounded">
            <span className="font-medium">B.</span> {taskB.title} · £{taskB.reward}
          </div>
        </div>
        <div className="space-y-2">
          <button onClick={() => onResolve('self')} className="block w-full bg-red-100 text-red-800 py-2 rounded text-sm hover:bg-red-200">
            硬扛两个 (-30 energy, -3 学业, -0.02 评分)
          </button>
          <button onClick={() => onResolve('decline_a')} className="block w-full bg-gray-100 text-gray-800 py-2 rounded text-sm hover:bg-gray-200">
            拒掉 A 保 B
          </button>
          <button onClick={() => onResolve('decline_b')} className="block w-full bg-gray-100 text-gray-800 py-2 rounded text-sm hover:bg-gray-200">
            拒掉 B 保 A
          </button>
          {hasTeam && (
            <button onClick={() => onResolve('team')} className="block w-full bg-purple-100 text-purple-800 py-2 rounded text-sm hover:bg-purple-200">
              转 A 给团员处理 (-15% cut)
            </button>
          )}
        </div>
        <button onClick={onClose} className="mt-3 text-xs text-gray-500 underline">稍后再说</button>
      </div>
    </div>
  );
}
