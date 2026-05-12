import React, { useState } from 'react';
import { BottomSheet } from './BottomSheet.jsx';

// 5 stat 颜色映射：与 PlayingScreen header 现有逻辑保持一致
function statColor(name, value) {
  if (name === 'academic') {
    if (value >= 70) return '#22c55e';
    if (value >= 50) return undefined;
    if (value >= 35) return '#f97316';
    return '#ef4444';
  }
  if (name === 'wallet') {
    if (value < 0) return '#ef4444';
    if (value < 150) return '#f97316';
    if (value < 400) return '#eab308';
    if (value < 800) return undefined;
    return '#22c55e';
  }
  if (name === 'energy') {
    if (value >= 75) return '#22c55e';
    if (value >= 50) return undefined;
    if (value >= 25) return '#eab308';
    if (value >= 10) return '#f97316';
    return '#ef4444';
  }
  if (name === 'stress') {
    if (value >= 85) return '#ef4444';
    if (value >= 75) return '#f97316';
    if (value >= 60) return '#eab308';
    if (value >= 30) return undefined;
    return '#22c55e';
  }
  if (name === 'belonging') {
    if (value >= 75) return '#22c55e';
    if (value >= 50) return '#a0c890';
    if (value >= 30) return undefined;
    if (value >= 15) return '#f97316';
    return '#ef4444';
  }
  return undefined;
}

function statLabel(name, value) {
  if (name === 'energy') {
    if (value >= 75) return '充沛'; if (value >= 50) return '还行';
    if (value >= 25) return '疲惫'; if (value >= 10) return '虚脱'; return '濒崩';
  }
  if (name === 'stress') {
    if (value >= 95) return '崩盘'; if (value >= 85) return '濒崩';
    if (value >= 75) return '紧绷'; if (value >= 60) return '有点累';
    if (value >= 30) return '能扛'; return '平静';
  }
  if (name === 'belonging') {
    if (value >= 75) return '找到了'; if (value >= 50) return '渐入佳境';
    if (value >= 30) return '适应中'; if (value >= 15) return '有点疏离'; return '孤岛感';
  }
  return null;
}

function StatRow({ icon, name, statKey, value, displayValue }) {
  const color = statColor(statKey, value);
  const fillPct = Math.max(0, Math.min(100, statKey === 'wallet' ? Math.min(100, value/10) : value));
  return (
    <div className="grid grid-cols-[80px_1fr_60px] items-center gap-2 mb-1.5 text-sm">
      <span className="opacity-75">{icon} {name}</span>
      <div className="h-1 bg-current/10 relative">
        <div className="absolute inset-y-0 left-0 transition-all"
             style={{ width: `${fillPct}%`, background: color || '#d4b070' }} />
      </div>
      <span className="text-right text-xs" style={{ fontFamily: 'monospace', color }}>
        {displayValue}
      </span>
    </div>
  );
}

export function BagSheet({
  open, onClose,
  stats, mealsToday,
  weekInfo, attendanceRate, classesAttendedThisWeek,
  dissertationProgress, dissertationTopic,
  muted, onToggleMute, onRestart,
}) {
  const [confirmRestart, setConfirmRestart] = useState(false);

  const mealColor = mealsToday >= 2 ? '#22c55e' : mealsToday === 1 ? '#eab308' : '#ef4444';

  return (
    <BottomSheet open={open} onClose={() => { setConfirmRestart(false); onClose(); }} title="🎒 背包">
      {/* ── 完整状态 ── */}
      <section className="mb-4 p-3 border border-current/20">
        <div className="text-[10px] tracking-[0.2em] opacity-50 mb-2"
             style={{ fontFamily: 'monospace' }}>完整状态</div>
        <StatRow icon="📚" name="学业" statKey="academic" value={stats.academic}
          displayValue={`${stats.academic}%`} />
        <StatRow icon="💰" name="钱包" statKey="wallet" value={stats.wallet}
          displayValue={`£${stats.wallet}`} />
        <StatRow icon="💪" name="精力" statKey="energy" value={stats.energy}
          displayValue={statLabel('energy', stats.energy)} />
        <StatRow icon="🧠" name="压力" statKey="stress" value={stats.stress}
          displayValue={statLabel('stress', stats.stress)} />
        <StatRow icon="🏠" name="归属" statKey="belonging" value={stats.belonging}
          displayValue={statLabel('belonging', stats.belonging)} />
        <div className="flex justify-between items-center mt-2 text-xs"
             style={{ fontFamily: 'monospace' }}>
          <span className="opacity-75">🍴 今日餐</span>
          <span style={{ color: mealColor }}>{mealsToday}/2 顿</span>
        </div>
      </section>

      {/* ── 本周 ── */}
      <section className="mb-4 p-3 border border-current/20">
        <div className="text-[10px] tracking-[0.2em] opacity-50 mb-2"
             style={{ fontFamily: 'monospace' }}>本周</div>
        <div className="flex justify-between text-sm py-0.5">
          <span className="opacity-75">周类型</span>
          <span style={{ fontFamily: 'monospace', color: '#d4b070' }}>{weekInfo?.cn || '—'}</span>
        </div>
        <div className="flex justify-between text-sm py-0.5">
          <span className="opacity-75">出勤累计</span>
          <span style={{ fontFamily: 'monospace', color: '#d4b070' }}>{attendanceRate}%</span>
        </div>
        <div className="flex justify-between text-sm py-0.5">
          <span className="opacity-75">本周课</span>
          <span style={{ fontFamily: 'monospace', color: '#d4b070' }}>{classesAttendedThisWeek}/6</span>
        </div>
        {weekInfo?.type === 'dissertation' && dissertationTopic && (
          <>
            <div className="flex justify-between text-sm py-0.5 mt-2 pt-2 border-t border-current/10">
              <span className="opacity-75">论文进度</span>
              <span style={{ fontFamily: 'monospace', color: '#d4b070' }}>{dissertationProgress}%</span>
            </div>
            <div className="text-xs opacity-60 italic mt-1">题目：{dissertationTopic.label}</div>
          </>
        )}
      </section>

      {/* ── 设置 ── */}
      <section className="mb-2 p-3 border border-current/20">
        <div className="text-[10px] tracking-[0.2em] opacity-50 mb-2"
             style={{ fontFamily: 'monospace' }}>设置</div>
        <button onClick={onToggleMute}
          className="w-full text-left p-3 mb-2 border border-current/40 hover:border-current hover:bg-current/5 active:bg-current/10 transition-all text-sm flex items-center justify-between min-h-[44px]">
          <span>{muted ? '🔇 已静音' : '🔊 声音开'}</span>
          <span className="text-xs opacity-50" style={{ fontFamily: 'monospace' }}>{muted ? 'OFF' : 'ON'}</span>
        </button>
        {!confirmRestart ? (
          <button onClick={() => setConfirmRestart(true)}
            className="w-full text-left p-3 border border-current/40 hover:border-red-400 hover:bg-red-400/5 active:bg-red-400/10 transition-all text-sm min-h-[44px]">
            🗑️ 清空存档 · 重新开始
          </button>
        ) : (
          <div className="border border-red-400/60 p-3 bg-red-400/5">
            <div className="text-xs opacity-80 italic mb-3" style={{ lineHeight: '1.7' }}>
              真的要清空当前进度并重开吗？这一年的所有选择都会消失。
            </div>
            <div className="flex gap-2">
              <button onClick={() => { setConfirmRestart(false); onClose(); onRestart(); }}
                className="flex-1 py-2 border border-red-400/60 text-red-300 hover:bg-red-400/10 active:bg-red-400/15 text-xs tracking-[0.2em] min-h-[44px]">
                确认
              </button>
              <button onClick={() => setConfirmRestart(false)}
                className="flex-1 py-2 border border-current/40 hover:border-current active:bg-current/10 text-xs tracking-[0.2em] min-h-[44px]">
                取消
              </button>
            </div>
          </div>
        )}
        <div className="mt-3 pt-2 border-t border-current/10 text-xs opacity-50 italic" style={{ lineHeight: '1.6' }}>
          每次行动会自动存档到本地。
        </div>
      </section>
    </BottomSheet>
  );
}
