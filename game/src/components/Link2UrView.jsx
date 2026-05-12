import React, { useState, useEffect, useRef } from 'react';
import { LINK2UR_BRAND, availablePosts } from '../data/link2ur.js';
import { LINK2UR_REVIEWS } from '../data/link2urReviews.js';
import { renderLink2UrWall, renderWallToBlob } from '../engine/link2urWall.js';
import { download } from '../engine/diaryExport.js';

const PRIMARY = LINK2UR_BRAND.primary;   // #007AFF
const ACCENT = LINK2UR_BRAND.accent;     // #FF8033
const GOLD = LINK2UR_BRAND.gold;         // #FFD700

function Stars({ rating }) {
  const filled = Math.round(rating);
  return (
    <span style={{ color: GOLD, letterSpacing: '0.05em' }}>
      {'★'.repeat(filled)}{'☆'.repeat(5 - filled)}
    </span>
  );
}

export function Link2UrView({
  board, completed, posted, rating, earnings, walletNow, actionsLeft, postsAvailable,
  flags, gameState, onComplete, onPost, week, onApply,
}) {
  const [tab, setTab] = useState('accept');
  const [wallOpen, setWallOpen] = useState(false);

  const completedCount = completed?.length || 0;
  const reviewState = { flags: flags || {}, link2urCompleted: completed, link2urRating: rating };
  const unlockedReviews = LINK2UR_REVIEWS.filter(r => {
    try { return !!r.condition(reviewState); } catch (_) { return false; }
  });

  // Pending applications + rejected history (Phase 4 UI)
  const pending = gameState?.link2urPending || [];
  const rejected = gameState?.link2urRejected || [];
  // 是否有 emergency post（urgent 标记的）—— 用于在 post tab 上加 red dot
  const urgentPostCount = postsAvailable.filter(p => p.urgent).length;

  return (
    <div className="animate-fadein">
      {/* Header — Link2Ur brand bar */}
      <div className="mb-3 px-3 py-2.5 border flex items-center justify-between"
        style={{ borderColor: PRIMARY + '60', background: PRIMARY + '12' }}>
        <div>
          <div className="flex items-center gap-2">
            <div className="w-6 h-6 rounded flex items-center justify-center text-xs font-bold"
              style={{ background: PRIMARY, color: 'white' }}>L</div>
            <div className="text-base font-medium" style={{ color: PRIMARY }}>Link2Ur</div>
            <div className="text-xs opacity-60 italic">{LINK2UR_BRAND.tagline}</div>
          </div>
        </div>
        <div className="text-right text-xs" style={{ fontFamily: 'monospace' }}>
          <div><Stars rating={rating} /> {rating.toFixed(1)}</div>
          <div className="opacity-60 mt-0.5">£{earnings} 已赚 · {completedCount} 单</div>
        </div>
      </div>

      {/* Export wall button */}
      <button
        onClick={() => setWallOpen(true)}
        className="w-full mb-3 py-2 border text-xs tracking-[0.2em] transition-colors flex items-center justify-center gap-2"
        style={{ borderColor: GOLD + '70', color: GOLD, background: GOLD + '08' }}
        onMouseEnter={(e) => { e.currentTarget.style.background = GOLD + '18'; }}
        onMouseLeave={(e) => { e.currentTarget.style.background = GOLD + '08'; }}>
        <span>📸</span>
        <span>导出我的成就墙 · 朋友圈分享卡</span>
      </button>

      {/* sub-tab switcher · 4 tabs */}
      <div className="grid grid-cols-4 gap-1 mb-3 text-xs">
        <button onClick={() => setTab('accept')}
          className={`py-2 border ${tab === 'accept' ? 'bg-current/10' : 'border-current/30 opacity-60'}`}
          style={tab === 'accept' ? { borderColor: PRIMARY, color: PRIMARY } : {}}>
          📥 接单 · {board.length}
        </button>
        <button onClick={() => setTab('post')}
          className={`py-2 border relative ${tab === 'post' ? 'bg-current/10' : 'border-current/30 opacity-60'}`}
          style={tab === 'post' ? { borderColor: ACCENT, color: ACCENT } : {}}>
          📤 发单 · {postsAvailable.length}
          {urgentPostCount > 0 && (
            <span className="absolute -top-1 -right-1 w-3 h-3 rounded-full"
              style={{ background: '#ef4444', boxShadow: '0 0 6px #ef4444' }} />
          )}
        </button>
        <button onClick={() => setTab('applications')}
          className={`py-2 border ${tab === 'applications' ? 'bg-current/10' : 'border-current/30 opacity-60'}`}
          style={tab === 'applications' ? { borderColor: '#eab308', color: '#eab308' } : {}}>
          📋 申请 · {pending.length}
        </button>
        <button onClick={() => setTab('reviews')}
          className={`py-2 border ${tab === 'reviews' ? 'bg-current/10' : 'border-current/30 opacity-60'}`}
          style={tab === 'reviews' ? { borderColor: GOLD, color: GOLD } : {}}>
          ⭐ 评价 · {unlockedReviews.length}
        </button>
      </div>

      {tab === 'accept' && (
        <AcceptList board={board} actionsLeft={actionsLeft}
          onApply={onApply} rating={rating} completedCount={completedCount} week={week} />
      )}
      {tab === 'post' && (
        <PostList postsAvailable={postsAvailable} posted={posted} walletNow={walletNow} onPost={onPost} />
      )}
      {tab === 'applications' && (
        <ApplicationsList pending={pending} rejected={rejected} day={gameState?.day}
          actionsLeft={actionsLeft} onComplete={onComplete} />
      )}
      {tab === 'reviews' && (
        <ReviewList reviews={unlockedReviews} totalReviews={LINK2UR_REVIEWS.length} />
      )}

      <div className="mt-4 text-xs opacity-40 italic text-center" style={{ lineHeight: '1.7' }}>
        Link2Ur · 留学生互助平台 · 任务每周一刷新<br/>
        接单赚钱 · 发单解放时间
      </div>

      {wallOpen && gameState && (
        <Link2UrWallModal gameState={gameState} onClose={() => setWallOpen(false)} />
      )}
    </div>
  );
}

function Link2UrWallModal({ gameState, onClose }) {
  const canvasRef = useRef(null);
  const [downloading, setDownloading] = useState(false);

  useEffect(() => {
    if (canvasRef.current) {
      renderLink2UrWall(canvasRef.current, gameState);
    }
  }, [gameState]);

  async function handleDownload() {
    setDownloading(true);
    try {
      const blob = await renderWallToBlob(gameState);
      const week = Math.ceil((gameState.day || 1) / 7);
      download(blob, `Link2Ur-成就墙-W${week}.png`);
    } finally {
      setDownloading(false);
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 animate-fadein"
      style={{ background: 'rgba(10, 8, 6, 0.92)' }}
      onClick={onClose}>
      <div className="max-w-md w-full" onClick={(e) => e.stopPropagation()}>
        <div className="text-xs tracking-[0.3em] opacity-60 mb-2 text-center" style={{ fontFamily: 'monospace', color: GOLD }}>
          ◆ LINK2UR · MY YEAR
        </div>
        <canvas ref={canvasRef} width={1080} height={1350}
          className="w-full mb-4 shadow-2xl"
          style={{ aspectRatio: '1080 / 1350' }} />
        <div className="flex gap-2">
          <button onClick={handleDownload} disabled={downloading}
            className="flex-1 py-2.5 border text-sm tracking-[0.3em] transition-colors"
            style={{ borderColor: GOLD + 'a0', color: GOLD, background: GOLD + '12' }}>
            {downloading ? '生成中...' : '↓ 下载 PNG'}
          </button>
          <button onClick={onClose}
            className="flex-1 py-2.5 border border-current/40 hover:bg-current/5 transition-colors text-sm tracking-[0.3em]">
            关闭
          </button>
        </div>
        <div className="text-xs opacity-50 italic text-center mt-3" style={{ lineHeight: '1.7' }}>
          长按转发到微信 / 朋友圈 / 微博
        </div>
      </div>
    </div>
  );
}

function ApplicationsList({ pending, rejected, day, actionsLeft, onComplete }) {
  // 把 pending 拆成 等待中 / 已批准（可点完成）两组
  const waiting = pending.filter(p => p.status !== 'approved');
  const approved = pending.filter(p => p.status === 'approved');

  if (pending.length === 0 && rejected.length === 0) {
    return (
      <div className="p-6 border border-current/20 text-center text-xs opacity-60 italic" style={{ lineHeight: '1.9' }}>
        没有申请中的任务。<br/>
        申请提交后客户通常 12-36h 内回复，批准的任务出现在这里 → 点"完成"开工。
      </div>
    );
  }
  return (
    <div className="space-y-3">
      {approved.length > 0 && (
        <div>
          <div className="text-[10px] tracking-[0.2em] mb-1.5" style={{ fontFamily: 'monospace', color: '#22c55e' }}>
            ✅ 客户已确认 · 点完成即开工 ({approved.length})
          </div>
          <div className="space-y-1.5">
            {approved.map(p => (
              <div key={p.taskId} className="p-2.5 border rounded text-xs"
                style={{ borderColor: '#22c55e60', background: '#22c55e10' }}>
                <div className="flex justify-between items-baseline gap-2 mb-1">
                  <div className="flex items-center gap-2 flex-1 min-w-0">
                    <span>{p.emoji || '✅'}</span>
                    <span className="font-medium truncate">{p.title}</span>
                  </div>
                  <span className="text-[10px] flex-shrink-0" style={{ fontFamily: 'monospace', color: '#22c55e' }}>£{p.reward}</span>
                </div>
                <div className="flex justify-between items-center text-[10px] opacity-70 mb-2" style={{ fontFamily: 'monospace' }}>
                  <span>-{p.energyCost || 0} 精力 · 1 行动</span>
                  <span>客户 D{p.approvedDay} 已确认</span>
                </div>
                <button
                  onClick={() => onComplete && onComplete(p)}
                  disabled={actionsLeft <= 0}
                  className="w-full py-1.5 border text-xs tracking-[0.2em] transition-all disabled:opacity-30 disabled:cursor-not-allowed"
                  style={{ borderColor: '#22c55e', color: '#22c55e', background: '#22c55e08' }}>
                  {actionsLeft > 0 ? '完成 · 开工' : '行动已用完 · 明天再来'}
                </button>
              </div>
            ))}
          </div>
        </div>
      )}
      {waiting.length > 0 && (
        <div>
          <div className="text-[10px] tracking-[0.2em] opacity-60 mb-1.5" style={{ fontFamily: 'monospace' }}>
            ⏳ 等待客户回复 ({waiting.length})
          </div>
          <div className="space-y-1.5">
            {waiting.map(p => (
              <div key={p.taskId} className="p-2.5 border rounded text-xs"
                style={{ borderColor: '#eab30850', background: '#eab30810' }}>
                <div className="flex justify-between items-baseline gap-2 mb-1">
                  <div className="flex items-center gap-2 flex-1 min-w-0">
                    <span>{p.emoji || '⏳'}</span>
                    <span className="font-medium truncate">{p.title}</span>
                  </div>
                  <span className="text-[10px] flex-shrink-0" style={{ fontFamily: 'monospace', color: '#eab308' }}>£{p.reward}</span>
                </div>
                <div className="opacity-60 italic text-[10px]" style={{ lineHeight: '1.5' }}>
                  申请已 {(day || 0) - p.appliedDay} 天 · 预计 12-36h 内回复
                  {p.requirement && (
                    <span className="ml-1">
                      （门槛：{p.requirement.rating ? `评分≥${p.requirement.rating}` : ''}
                      {p.requirement.count ? ` · 完成≥${p.requirement.count}` : ''}）
                    </span>
                  )}
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
      {rejected.length > 0 && (
        <div>
          <div className="text-[10px] tracking-[0.2em] opacity-60 mb-1.5" style={{ fontFamily: 'monospace' }}>
            ❌ 历史拒绝 ({rejected.length})
          </div>
          <div className="space-y-1.5">
            {rejected.slice(0, 8).map(r => (
              <div key={r.id} className="p-2 border border-current/20 rounded text-[11px] opacity-75">
                <div className="flex justify-between items-baseline gap-2 mb-0.5">
                  <span className="font-medium truncate">{r.title}</span>
                  <span className="opacity-50 flex-shrink-0" style={{ fontFamily: 'monospace' }}>D{r.day}</span>
                </div>
                <div className="opacity-70 italic" style={{ lineHeight: '1.4' }}>{r.reason}</div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

function AcceptList({ board, actionsLeft, onApply, rating, completedCount, week }) {
  if (board.length === 0) {
    return (
      <div className="p-6 border border-current/20 text-center text-xs opacity-60 italic" style={{ lineHeight: '1.9' }}>
        本周任务都被接走了。<br/>
        下周一刷新——记得早起。
      </div>
    );
  }
  return (
    <div className="space-y-2">
      {board.map(t => {
        // 所有任务都走"申请"流程 —— 不立即完成，等客户 12-36h 后回复 approve/reject。
        // 有 requirement 的额外检查门槛是否满足，不满足直接 disable。
        const hasReq = !!t.requirement;
        const meetsBaseline = !hasReq || (
          (!t.requirement.rating || rating >= t.requirement.rating) &&
          (!t.requirement.count || completedCount >= t.requirement.count)
        );
        const borderColor = hasReq ? '#eab308' : PRIMARY;
        return (
          <div key={t.id} className="p-3 border" style={{ borderColor: borderColor + '60' }}>
            <div className="flex items-start gap-3">
              <div className="text-2xl flex-shrink-0">{t.emoji}</div>
              <div className="flex-1 min-w-0">
                <div className="flex justify-between items-baseline gap-2">
                  <div className="text-sm font-medium">{t.title}</div>
                  <div className="text-base font-medium flex-shrink-0" style={{ color: PRIMARY, fontFamily: 'monospace' }}>£{t.reward}</div>
                </div>
                <div className="text-xs opacity-70 italic mt-1" style={{ lineHeight: '1.6' }}>{t.desc}</div>
                {hasReq && (
                  <div className="mt-1.5 text-[10px] flex flex-wrap gap-1.5"
                    style={{ fontFamily: 'monospace' }}>
                    {t.requirement.rating && (
                      <span className="px-1.5 py-0.5 rounded"
                        style={{
                          background: rating >= t.requirement.rating ? '#22c55e25' : '#ef444425',
                          color: rating >= t.requirement.rating ? '#22c55e' : '#ef4444',
                        }}>
                        评分 ≥ {t.requirement.rating}（你 {rating.toFixed(1)}）
                      </span>
                    )}
                    {t.requirement.count && (
                      <span className="px-1.5 py-0.5 rounded"
                        style={{
                          background: completedCount >= t.requirement.count ? '#22c55e25' : '#ef444425',
                          color: completedCount >= t.requirement.count ? '#22c55e' : '#ef4444',
                        }}>
                        完成 ≥ {t.requirement.count}（你 {completedCount}）
                      </span>
                    )}
                  </div>
                )}
                <div className="flex justify-between items-center mt-2 text-xs opacity-60" style={{ fontFamily: 'monospace' }}>
                  <span>-{t.energyCost} 精力 · 接到后扣行动</span>
                  <span><Stars rating={t.rating} /></span>
                </div>
                <button
                  onClick={() => onApply(t)}
                  disabled={!meetsBaseline}
                  className="w-full mt-2 py-1.5 border text-xs tracking-[0.2em] transition-all disabled:opacity-30 disabled:cursor-not-allowed"
                  style={{
                    borderColor,
                    color: borderColor,
                    background: 'transparent',
                  }}>
                  {meetsBaseline
                    ? (hasReq ? '申请（高门槛 · 客户审核 ~24h）' : '申请（等客户确认 ~24h）')
                    : '门槛不够 · 点亮才能申请'}
                </button>
              </div>
            </div>
          </div>
        );
      })}
    </div>
  );
}

function ReviewList({ reviews, totalReviews }) {
  if (reviews.length === 0) {
    return (
      <div className="p-6 border border-current/20 text-center text-xs opacity-60 italic" style={{ lineHeight: '1.9' }}>
        暂时还没有具名评价。<br/>
        多接几单 + 在游戏里和朋友建立关系，<br/>
        他们会反过来在 Link2Ur 上写你。
      </div>
    );
  }
  return (
    <div className="space-y-2">
      <div className="text-xs opacity-60 italic mb-1" style={{ lineHeight: '1.7' }}>
        来自你认识的人的留言。{reviews.length} / {totalReviews} 已解锁。
      </div>
      {reviews.map(r => (
        <div key={r.id} className="p-3 border" style={{ borderColor: GOLD + '50' }}>
          <div className="flex items-start gap-3">
            <div className="w-9 h-9 rounded-full flex items-center justify-center text-base flex-shrink-0"
              style={{ background: r.avatarColor + '30', border: `1px solid ${r.avatarColor}80` }}>
              {r.avatar}
            </div>
            <div className="flex-1 min-w-0">
              <div className="flex justify-between items-baseline gap-2">
                <div className="text-sm font-medium">{r.from}</div>
                <div className="text-xs opacity-50" style={{ fontFamily: 'monospace' }}>{r.weekHint}</div>
              </div>
              <div className="text-xs opacity-60 italic">{r.role}</div>
              <div className="mt-1.5 text-xs" style={{ color: GOLD, letterSpacing: '0.05em' }}>
                {'★'.repeat(r.starCount)}{'☆'.repeat(5 - r.starCount)}
              </div>
              <div className="mt-2 text-xs whitespace-pre-line" style={{ lineHeight: '1.7' }}>
                {r.message}
              </div>
            </div>
          </div>
        </div>
      ))}
    </div>
  );
}

function PostList({ postsAvailable, posted, walletNow, onPost }) {
  const remaining = postsAvailable.filter(p => !posted.includes(p.id));
  if (remaining.length === 0) {
    return (
      <div className="p-6 border border-current/20 text-center text-xs opacity-60 italic" style={{ lineHeight: '1.9' }}>
        当前没有适合的发单类型。<br/>
        遇到具体麻烦时这里会出现可发单。
      </div>
    );
  }
  return (
    <div className="space-y-2">
      <div className="text-xs opacity-60 italic mb-1" style={{ lineHeight: '1.7' }}>
        付钱让别人替你跑——花钱省时间。每个任务只能发一次。
      </div>
      {/* 紧迫 posts 先排前面 */}
      {remaining.sort((a, b) => (b.urgent ? 1 : 0) - (a.urgent ? 1 : 0)).map(p => {
        const cantAfford = walletNow < p.cost;
        const borderColor = p.urgent ? '#ef4444' : ACCENT;
        return (
          <div key={p.id} className="p-3 border relative"
            style={{
              borderColor: borderColor + (p.urgent ? '90' : '40'),
              background: p.urgent ? '#ef444408' : undefined,
            }}>
            {p.urgent && (
              <div className="absolute top-1 right-1 px-1.5 py-0.5 rounded text-[9px] font-bold"
                style={{ background: '#ef4444', color: 'white', letterSpacing: '0.1em' }}>
                ⚠ 急
              </div>
            )}
            <div className="flex items-start gap-3">
              <div className="text-2xl flex-shrink-0">{p.emoji}</div>
              <div className="flex-1 min-w-0">
                <div className="flex justify-between items-baseline gap-2">
                  <div className="text-sm font-medium">{p.title}</div>
                  <div className="text-base font-medium flex-shrink-0"
                    style={{ color: borderColor, fontFamily: 'monospace' }}>-£{p.cost}</div>
                </div>
                <div className="text-xs opacity-70 italic mt-1" style={{ lineHeight: '1.6' }}>{p.desc}</div>
                <div className="text-xs opacity-60 mt-2" style={{ fontFamily: 'monospace' }}>
                  {p.energyGain ? `+${p.energyGain} 精力` : ''}
                  {p.actionGain ? `${p.energyGain ? ' · ' : ''}+${p.actionGain} 行动` : ''}
                  {p.academicGain ? `${(p.energyGain || p.actionGain) ? ' · ' : ''}+${p.academicGain} 学业` : ''}
                </div>
                <button
                  onClick={() => onPost(p)}
                  disabled={cantAfford}
                  className="w-full mt-2 py-1.5 border text-xs tracking-[0.2em] transition-all disabled:opacity-30 disabled:cursor-not-allowed"
                  style={{
                    borderColor: ACCENT,
                    color: ACCENT,
                  }}
                  onMouseEnter={(e) => { if (!e.currentTarget.disabled) { e.currentTarget.style.background = ACCENT; e.currentTarget.style.color = 'white'; } }}
                  onMouseLeave={(e) => { e.currentTarget.style.background = 'transparent'; e.currentTarget.style.color = ACCENT; }}>
                  {cantAfford ? '钱不够' : '发单'}
                </button>
              </div>
            </div>
          </div>
        );
      })}
    </div>
  );
}
