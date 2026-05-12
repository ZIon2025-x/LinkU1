import React, { useEffect } from 'react';

// 通用 bottom-sheet：mobile 从底滑入，md+ 退化成居中 modal
// API:
//   open       : boolean
//   onClose    : () => void
//   title      : ReactNode (可选)
//   footer     : ReactNode (可选, sticky 底部)
//   children   : 内容区（独立滚动）
//   data-testid: 透传给最外层 div，便于测试 backdrop 选择
export function BottomSheet({ open, onClose, title, footer, children, ...rest }) {
  useEffect(() => {
    if (!open) return;
    const onKey = (e) => { if (e.key === 'Escape') onClose(); };
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  }, [open, onClose]);

  if (!open) return null;

  const tid = rest['data-testid'];

  return (
    <div
      className="fixed inset-0 z-50 bg-black/85 backdrop-blur-sm
                 flex items-end justify-center
                 md:items-center md:p-4
                 animate-fadein"
      data-testid={tid ? `${tid}-backdrop` : undefined}
      onClick={onClose}
    >
      <div
        className="bg-[#1a1612] border border-current/40
                   w-full max-h-[90dvh]
                   rounded-t-2xl
                   md:rounded-2xl md:max-w-md md:w-auto
                   flex flex-col
                   animate-slide-up-sheet
                   md:animate-fadein
                   pb-[env(safe-area-inset-bottom)]
                   md:pb-0"
        onClick={(e) => e.stopPropagation()}
        {...(tid ? { 'data-testid': tid } : {})}
      >
        {/* 顶部 handle（视觉装饰，无拖动手势） */}
        <div className="md:hidden flex justify-center pt-2 pb-1 flex-shrink-0">
          <div className="w-9 h-1 rounded-full bg-current/30" />
        </div>
        {title && (
          <div className="px-5 pt-1 pb-2 flex-shrink-0 text-center text-xs tracking-[0.3em] opacity-70"
               style={{ fontFamily: 'monospace', color: '#d4b070' }}>
            {title}
          </div>
        )}
        <div className="flex-1 overflow-y-auto px-5 py-3">
          {children}
        </div>
        {footer && (
          <div className="px-5 py-3 border-t border-current/15 flex-shrink-0">
            {footer}
          </div>
        )}
      </div>
    </div>
  );
}
