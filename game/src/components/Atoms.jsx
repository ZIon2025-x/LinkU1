import React from 'react';

export function TabBtn({ active, onClick, children }) {
  return (
    <button onClick={onClick}
      className={`py-2 border transition-all ${active ? 'border-current bg-current/10' : 'border-current/30 opacity-60 hover:opacity-100'}`}>
      {children}
    </button>
  );
}

export function MiniStat({ label, value, unit }) {
  return (
    <div className="border border-current/20 p-2 text-center">
      <div className="opacity-60 text-xs" style={{ fontFamily: 'monospace' }}>{label}</div>
      <div className="text-sm mt-0.5" style={{ fontFamily: 'monospace' }}>{value}{unit}</div>
    </div>
  );
}
