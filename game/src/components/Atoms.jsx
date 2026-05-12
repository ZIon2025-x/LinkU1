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
