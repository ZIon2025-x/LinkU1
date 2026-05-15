import React, { useEffect } from 'react';

export function MinigameHelpButton({ onClick }) {
  return (
    <button
      onClick={onClick}
      title="玩法说明"
      aria-label="玩法说明"
      className="absolute top-3 right-3 w-7 h-7 flex items-center justify-center
                 border border-current/40 rounded-full text-sm
                 hover:bg-current/10 transition-colors"
      style={{ fontFamily: 'monospace' }}
    >
      ?
    </button>
  );
}

export function MinigameRulesModal({ open, onClose, title, children }) {
  useEffect(() => {
    if (!open) return;
    const handler = (e) => { if (e.key === 'Escape') onClose(); };
    window.addEventListener('keydown', handler);
    return () => window.removeEventListener('keydown', handler);
  }, [open, onClose]);

  if (!open) return null;

  return (
    <div
      data-testid="rules-modal-backdrop"
      onClick={onClose}
      className="fixed inset-0 z-[60] flex items-center justify-center p-4 animate-fadein"
      style={{ background: 'rgba(10, 8, 6, 0.85)' }}
    >
      <div
        onClick={(e) => e.stopPropagation()}
        className="bg-[#1a1612] border border-current/50 max-w-md w-full p-5 max-h-[85vh] overflow-y-auto"
      >
        <div
          className="text-xs tracking-[0.3em] mb-3 opacity-60"
          style={{ fontFamily: 'monospace' }}
        >
          📖 {title}
        </div>
        <div className="text-sm" style={{ lineHeight: '1.85' }}>
          {children}
        </div>
        <button
          onClick={onClose}
          className="w-full mt-4 py-2 border border-current text-xs tracking-[0.2em]
                     hover:bg-current hover:text-black transition-colors"
        >
          明白了
        </button>
      </div>
    </div>
  );
}
