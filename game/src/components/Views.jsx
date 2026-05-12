import React, { useState, useMemo } from 'react';
import {
  NPCS, STORYLINES, LOCATIONS, TRAVEL_DESTINATIONS, EXAM_PAPERS,
  GROUP_MEMBERS, STRANGERS, DREAMS, INSOMNIA_THOUGHTS, NOSTALGIA_MOMENTS,
} from '../data/index.js';
import { CHAT_NPC_META, getChatOptions, getGroupOptions } from '../data/chatTopics.js';
import { INTERACTIVE_NPC_IDS } from '../engine/state.js';
import { AchievementCardModal, WrappedPosterModal } from './AchievementsView.jsx';
import { NpcAvatar } from './NpcAvatar.jsx';
import { getLocationImage, getMiscImage, getNpcImage, getAchievementImage } from '../engine/imageRegistry.js';
import { ACHIEVEMENT_BY_ID, TIER_META } from '../data/achievements.js';
import { pronounize } from '../engine/pronouns.js';

// Schematic London map · 10 个地点的绝对定位（百分比）。
// 大致按真实地理但压缩到竖屏画布上：King's X 在顶 / Tate 在底 / Hyde Park 西。
// 画师画 background image 时按这个分布画地标更顺。
// 坐标已对齐 src/assets/illustrations/misc/map-bg.png 实际画作位置
const MAP_MARKER_POSITIONS = {
  station: { x: '50%', y: '10%' },   // King's Cross 顶部红砖拱顶
  pub:     { x: '14%', y: '14%' },   // Camden 拱桥 · 偏左
  uni:     { x: '42%', y: '22%' },   // SOAS art deco 左塔
  library: { x: '68%', y: '22%' },   // Senate House 右塔
  flat:    { x: '48%', y: '39%' },   // 公寓 · 中央红砖 home base
  tesco:   { x: '17%', y: '48%' },   // 蓝白小店 · 最左
  soho:    { x: '44%', y: '58%' },   // 霓虹簇
  mei:     { x: '78%', y: '57%' },   // Chinatown 牌坊 · 最右
  park:    { x: '17%', y: '72%' },   // Hyde Park 树+湖 · 偏左下
  tate:    { x: '54%', y: '86%' },   // Tate Modern 砖红烟囱 · 底
};

const MapMarker = React.memo(function MapMarker({ loc, pos, isHome, isSelected, onClick }) {
  return (
    <button
      onClick={onClick}
      style={{ left: pos.x, top: pos.y }}
      // ::before 透明扩展点击热区到 ~44px (Apple HIG 推荐)，不影响视觉布局
      // 视觉点仍是 12px (w-3 h-3)，但手指点周围 16px 也能触发
      className="absolute -translate-x-1/2 -translate-y-1/2 z-10 group focus:outline-none
        before:content-[''] before:absolute before:left-1/2 before:top-1/2
        before:-translate-x-1/2 before:-translate-y-1/2 before:w-11 before:h-11"
    >
      {/* 选中时的 ring pulse */}
      {isSelected && (
        <div className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2
          w-8 h-8 rounded-full border-2 border-amber-400 animate-ping opacity-75" />
      )}
      <div className={`relative w-3 h-3 rounded-full border ${
        isSelected
          ? 'bg-amber-400 border-amber-200 shadow-[0_0_8px_2px_rgba(251,191,36,0.6)]'
          : isHome
          ? 'bg-orange-400 border-orange-200'
          : 'bg-stone-100/90 border-stone-700'
      } group-hover:scale-150 transition-transform`} />
      <div className={`absolute left-1/2 -translate-x-1/2 mt-1 whitespace-nowrap
        text-[10px] tracking-wide font-medium pointer-events-none
        ${isSelected ? 'text-amber-200' : 'text-stone-100'}`}
        style={{ textShadow: '0 1px 2px rgba(0,0,0,0.95), 0 0 4px rgba(0,0,0,0.7)' }}>
        {loc.name}
      </div>
    </button>
  );
});

// 出行方式费用 —— 全游戏统一 flat fare（伦敦市内通勤）。
// bus / tube：£2.50 · -1 action · -3 精力
// taxi (Uber)：£12 · -0 action · -1 精力
export const TRANSIT_COSTS = {
  bus:  { fare: 2.5,  action: 1, energy: 3,  emoji: '🚌', label: '公交 / Tube', sub: '便宜 · 但要花 1 个行动点' },
  taxi: { fare: 12,   action: 0, energy: 1,  emoji: '🚕', label: 'Uber',          sub: '贵 · 不消耗行动点' },
};

function LocationSheet({ loc, actionsLeft, wallet, onClose, onGoBus, onGoTaxi }) {
  const bus = TRANSIT_COSTS.bus;
  const taxi = TRANSIT_COSTS.taxi;
  const busDisabled = actionsLeft < bus.action || wallet < bus.fare;
  const taxiDisabled = wallet < taxi.fare;
  return (
    <>
      {/* 半透明背景 · 点外面关闭 */}
      <div onClick={onClose}
        className="absolute inset-0 bg-black/40 z-20 animate-fadein" />
      {/* 抽屉 · slide up from bottom */}
      <div className="absolute left-0 right-0 bottom-0 z-30 bg-[#1a1612] border-t border-amber-300/30
        animate-slide-up-sheet rounded-t-lg shadow-2xl">
        <div className="p-5">
          <div className="flex items-start gap-3 mb-3">
            <div className="text-3xl">{loc.emoji}</div>
            <div className="flex-1 min-w-0">
              <div className="text-lg font-medium text-stone-100">{loc.name}</div>
              <div className="text-xs italic opacity-50 text-stone-300">{loc.en}</div>
            </div>
            <button onClick={onClose}
              className="text-stone-400 hover:text-stone-100 text-xl leading-none px-2">×</button>
          </div>
          <div className="text-sm leading-relaxed opacity-80 text-stone-200 mb-4">
            {loc.desc}
          </div>
          <div className="text-[10px] tracking-[0.2em] opacity-50 mb-2"
            style={{ fontFamily: 'monospace' }}>怎么去 ·</div>
          <div className="grid grid-cols-2 gap-2 mb-2">
            <button onClick={onGoBus} disabled={busDisabled}
              className="p-3 border border-stone-500 text-stone-100 text-left transition-all
                hover:border-amber-300 hover:bg-amber-300/10 disabled:opacity-30 disabled:cursor-not-allowed">
              <div className="text-lg leading-none mb-1">{bus.emoji}</div>
              <div className="text-sm font-medium">{bus.label}</div>
              <div className="text-[10px] opacity-60 mt-1" style={{ fontFamily: 'monospace' }}>
                £{bus.fare} · -{bus.energy} 精力<br/>消耗 {bus.action} 行动
              </div>
            </button>
            <button onClick={onGoTaxi} disabled={taxiDisabled}
              className="p-3 border border-stone-500 text-stone-100 text-left transition-all
                hover:border-amber-300 hover:bg-amber-300/10 disabled:opacity-30 disabled:cursor-not-allowed">
              <div className="text-lg leading-none mb-1">{taxi.emoji}</div>
              <div className="text-sm font-medium">{taxi.label}</div>
              <div className="text-[10px] opacity-60 mt-1" style={{ fontFamily: 'monospace' }}>
                £{taxi.fare} · -{taxi.energy} 精力<br/>不耗行动
              </div>
            </button>
          </div>
          <button onClick={onClose}
            className="w-full py-2 border border-stone-700 text-stone-400 text-xs tracking-widest
              hover:border-stone-500 hover:text-stone-200 transition-colors">
            返回
          </button>
        </div>
      </div>
    </>
  );
}

export function MapView({ locations, actionsLeft, onGoToLocation, currentLocation, setCurrentLocation,
  onAttendClass, onWorkShift, onRestAtFlat, onCallHome, onTalkNPC, npcRel, day, stats, onStartTravel,
  onStudyAtFlat, onStudyAtLibrary, onStudyAtUni, onActivity,
  onWriteDissertation, weekInfo, dissertationTopic, week,
  onTriggerPret, onTriggerEssay, onTriggerMatch, gender }) {

  const [selectedLoc, setSelectedLoc] = useState(null);

  if (currentLocation) {
    return <LocationView location={currentLocation} onLeave={() => setCurrentLocation(null)}
      onAttendClass={onAttendClass} onWorkShift={onWorkShift} onRestAtFlat={onRestAtFlat}
      onStudyAtFlat={onStudyAtFlat} onStudyAtLibrary={onStudyAtLibrary} onStudyAtUni={onStudyAtUni}
      onActivity={onActivity}
      week={week}
      onCallHome={onCallHome} onTalkNPC={onTalkNPC} npcRel={npcRel} day={day} stats={stats}
      onStartTravel={onStartTravel} actionsLeft={actionsLeft}
      onWriteDissertation={onWriteDissertation}
      weekInfo={weekInfo}
      dissertationTopic={dissertationTopic}
      onTriggerPret={onTriggerPret}
      onTriggerEssay={onTriggerEssay}
      onTriggerMatch={onTriggerMatch}
      gender={gender} />;
  }

  // 画师画完后放到 src/assets/illustrations/misc/map-bg.png 自动 hot-swap
  const mapBg = getMiscImage('map-bg');

  return (
    <div className="relative w-full overflow-hidden animate-fadein"
      style={{ aspectRatio: '2 / 3', background: '#0a0807' }}>
      {/* 背景图 · 占位时显示渐变 */}
      {mapBg ? (
        <img src={mapBg} alt="London"
          className="absolute inset-0 w-full h-full object-cover" />
      ) : (
        <div className="absolute inset-0"
          style={{
            background: 'radial-gradient(ellipse at 50% 38%, #2a2620 0%, #1a1612 45%, #0a0807 100%)',
          }} />
      )}
      {/* 暗化叠加 · 让 marker 文字更易读 */}
      <div className="absolute inset-0 bg-black/25 pointer-events-none" />

      {/* 顶部 caption */}
      <div className="absolute top-2 left-2 right-2 z-10 flex justify-between items-center
        text-[10px] tracking-[0.25em] uppercase opacity-60 pointer-events-none">
        <span>Day {day} · 今天去哪</span>
        <span>{actionsLeft} 行动</span>
      </div>

      {/* 10 个 markers */}
      {locations.map(loc => {
        const pos = MAP_MARKER_POSITIONS[loc.id];
        if (!pos) return null;
        return (
          <MapMarker key={loc.id} loc={loc} pos={pos}
            isHome={loc.id === 'flat'}
            isSelected={selectedLoc?.id === loc.id}
            onClick={() => setSelectedLoc(loc)}
          />
        );
      })}

      {/* 底部抽屉 */}
      {selectedLoc && (
        <LocationSheet loc={selectedLoc} actionsLeft={actionsLeft} wallet={stats?.wallet || 0}
          onClose={() => setSelectedLoc(null)}
          onGoBus={() => { onGoToLocation(selectedLoc, 'bus'); setSelectedLoc(null); }}
          onGoTaxi={() => { onGoToLocation(selectedLoc, 'taxi'); setSelectedLoc(null); }}
        />
      )}
    </div>
  );
}

export function LocationView({ location, onLeave, onAttendClass, onWorkShift, onRestAtFlat,
  onCallHome, onTalkNPC, npcRel, day, week, stats, onStartTravel, actionsLeft,
  onStudyAtFlat, onStudyAtLibrary, onStudyAtUni, onActivity,
  onWriteDissertation, weekInfo, dissertationTopic,
  onTriggerPret, onTriggerEssay, onTriggerMatch, gender }) {

  const npcsHere = Object.values(NPCS).filter(n => n.locations.includes(location.id));

  // W2 起 → 公寓 / 图书馆 / 大学 都解锁固定"学习"行动
  const studyUnlocked = (week || 1) >= 2;

  // helper：把 activity definition 转成 LocationView 期望的 action 对象
  // 如果 effect.wallet 是负数且钱不够 → 自动 disable + 提示 "钱不够"
  // 第 5 参数 `opts.meal` 表示这是一次"吃饭"，会让 mealsToday +1
  const A = (label, desc, effect, eventChance, opts = {}) => {
    const cost = -(effect?.wallet || 0);
    const cantAfford = cost > 0 && (stats?.wallet ?? 0) < cost;
    return {
      label: cantAfford ? `${label}（钱不够 · 差 £${cost - (stats?.wallet ?? 0)}）` : label,
      desc,
      disabled: cantAfford,
      onClick: cantAfford
        ? undefined
        : () => onActivity && onActivity(location.id, { effect, eventChance, meal: opts.meal }),
    };
  };

  // 本地点的可用行动
  const actions = [];
  if (location.id === 'flat') {
    actions.push({ label: '🛌 休息', desc: '+25精力 -1归属', onClick: onRestAtFlat });
    actions.push({ label: '📞 给家里打电话', desc: '+10归属 -3精力', onClick: onCallHome });
    if (studyUnlocked) {
      actions.push({ label: '📝 在房间复习', desc: '+3学业 -8精力（家里效率低）', onClick: onStudyAtFlat });
    }
    actions.push(A('🍳 做顿饭 🍴', '-£8 +10精力 +3归属 -3压力 · 算 1 顿饭（30% 触发事件）',
      { wallet: -8, energy: 10, belonging: 3, stress: -3 }, 0.30, { meal: true }));
    actions.push(A('🚪 找室友闲聊', '-3精力 +5归属（35% 触发事件）',
      { energy: -3, belonging: 5 }, 0.35));
    if (weekInfo?.type === 'dissertation' && dissertationTopic) {
      actions.push({ label: '📝 写论文（在家）', desc: `+论文进度 -12精力`, onClick: onWriteDissertation });
      actions.push({ label: '✍️ 写一段（迷你游戏）', desc: '挑战自己 +大量论文进度', onClick: onTriggerEssay });
    }
  } else if (location.id === 'uni') {
    if (weekInfo?.requireClass) {
      actions.push({ label: '📚 上课', desc: '+6学业 -8精力 +1出勤', onClick: onAttendClass });
    }
    if (studyUnlocked) {
      actions.push({ label: '📖 大学自习', desc: '+4学业 -8精力（不算出勤）', onClick: onStudyAtUni });
    }
    actions.push(A('🚶 在 quad 散散步', '-2精力 +2归属（35% 触发事件）',
      { energy: -2, belonging: 2 }, 0.35));
    if (['reading', 'revision'].includes(weekInfo?.type)) {
      actions.push({ label: '🎴 复习理论卡牌', desc: '迷你游戏 +学业', onClick: onTriggerMatch });
    }
    if (weekInfo?.type === 'dissertation' && dissertationTopic) {
      actions.push({ label: '📝 论文 supervision meeting', desc: `+论文进度 -10精力`, onClick: onWriteDissertation });
    }
  } else if (location.id === 'library') {
    if (studyUnlocked) {
      actions.push({ label: '📚 图书馆自习', desc: '+6学业 -10精力 +1归属', onClick: onStudyAtLibrary });
    }
    actions.push(A('💡 翻参考书架', '-3精力 +1学业（30% 触发事件）',
      { energy: -3, academic: 1 }, 0.30));
    if (weekInfo?.type === 'dissertation' && dissertationTopic) {
      actions.push({ label: '📝 写论文（图书馆）', desc: `+论文进度(更高) -10精力`, onClick: onWriteDissertation });
      actions.push({ label: '✍️ 写一段（迷你游戏）', desc: '挑战自己 +大量论文进度', onClick: onTriggerEssay });
    }
    if (['reading', 'revision'].includes(weekInfo?.type)) {
      actions.push({ label: '🎴 复习理论卡牌', desc: '迷你游戏 +学业', onClick: onTriggerMatch });
    }
  } else if (location.id === 'mei') {
    actions.push(A('🍜 吃顿饭 🍴', '-£10 +10精力 +4归属 -3压力 · 算 1 顿饭（40% 触发事件）',
      { wallet: -10, energy: 10, belonging: 4, stress: -3 }, 0.40, { meal: true }));
    if (day > 14) actions.push({ label: '💼 打工一晚', desc: '+£50 -12精力', onClick: onWorkShift });
  } else if (location.id === 'pub') {
    actions.push(A('🍺 喝一杯', '-£5 -3精力 -2学业 +5归属（40% 触发事件）',
      { wallet: -5, energy: -3, academic: -2, belonging: 5 }, 0.40));
    actions.push(A('📺 看比赛', '-£4 -1精力 +6归属（35% 触发事件）',
      { wallet: -4, energy: -1, belonging: 6 }, 0.35));
    actions.push({ label: '💼 打工一晚', desc: '+£50 -12精力', onClick: onWorkShift });
  } else if (location.id === 'tesco') {
    actions.push(A('🛒 买菜买日用 🍴', '-£15 +3归属 -3压力 · 算 1 顿饭（晚上做饭）（20% 触发事件）',
      { wallet: -15, belonging: 3, stress: -3 }, 0.20, { meal: true }));
    actions.push(A('☕ Meal Deal 🍴', '-£4 +6精力 +2归属 -2压力 · 算 1 顿饭（20% 触发事件）',
      { wallet: -4, energy: 6, belonging: 2, stress: -2 }, 0.20, { meal: true }));
    actions.push(A('🏷️ 蹲黄标', '-3精力（30% 触发事件 · 抢到食物大赚）',
      { energy: -3 }, 0.30));
  } else if (location.id === 'park') {
    actions.push(A('🚶 闲逛半小时', '-3精力 +6归属 +2学业（思路清晰）（45% 触发事件）',
      { energy: -3, belonging: 6, academic: 2 }, 0.45));
    actions.push(A('🏃 晨跑', '-8精力 +5归属（30% 触发事件）',
      { energy: -8, belonging: 5 }, 0.30));
    actions.push(A('🐕 看狗 + 喂松鼠', '-1精力 +3归属（25% 触发事件）',
      { energy: -1, belonging: 3 }, 0.25));
  } else if (location.id === 'tate') {
    actions.push(A('🖼️ 看一场展', '-1精力 +4归属 +2学业（35% 触发事件）',
      { energy: -1, belonging: 4, academic: 2 }, 0.35));
    actions.push({ label: '☕ 去 Pret 点单（迷你游戏）', desc: '练你的英语听力', onClick: onTriggerPret });
  } else if (location.id === 'soho') {
    actions.push(A('🛍️ 逛 Selfridges/Liberty', '-£25 -2精力 +5归属（30% 触发事件）',
      { wallet: -25, energy: -2, belonging: 5 }, 0.30));
    actions.push(A('🥡 Chinatown 吃饭 🍴', '-£12 +8精力 +5归属 -3压力 · 算 1 顿饭（35% 触发事件）',
      { wallet: -12, energy: 8, belonging: 5, stress: -3 }, 0.35, { meal: true }));
    actions.push({ label: '☕ 去 Pret 点单（迷你游戏）', desc: '练你的英语听力', onClick: onTriggerPret });
  } else if (location.id === 'station') {
    TRAVEL_DESTINATIONS.forEach(d => {
      const cond = !d.condition || d.condition({ week: weekInfo?.week, day });
      if (cond) {
        actions.push({
          label: `🚆 去${d.name} (£${d.cost})`,
          desc: `${d.days}天，${d.desc}`,
          onClick: () => onStartTravel(d),
          disabled: stats.wallet < d.cost,
        });
      }
    });
  }

  const bannerUrl = getLocationImage(location.id);

  return (
    <div className="animate-fadein">
      <button onClick={onLeave} className="text-xs opacity-60 hover:opacity-100 mb-3">← 返回地图</button>
      <div className="border border-current/30 mb-3 overflow-hidden">
        {bannerUrl && (
          <div className="relative w-full" style={{ aspectRatio: '8 / 3' }}>
            <img src={bannerUrl} alt={location.name}
              className="w-full h-full object-cover" />
            <div className="absolute inset-0"
              style={{ background: 'linear-gradient(180deg, transparent 50%, rgba(10,8,6,0.85) 100%)' }} />
          </div>
        )}
        <div className="p-4">
          <div className="text-3xl mb-2">{location.emoji}</div>
          <div className="text-xl mb-1">{location.name}</div>
          <div className="text-xs opacity-60 italic mb-2">{location.en}</div>
          <div className="text-sm opacity-80">{location.desc}</div>
        </div>
      </div>

      {npcsHere.length > 0 && (
        <div className="mb-3">
          <div className="text-xs tracking-[0.2em] opacity-60 mb-2" style={{ fontFamily: 'monospace' }}>这里有人</div>
          <div className="space-y-2">
            {npcsHere.map(npc => {
              const rel = npcRel[npc.id] || 0;
              return (
                <button key={npc.id} onClick={() => onTalkNPC(npc)}
                  className="w-full flex items-center gap-3 p-3 border border-current/30 hover:border-current/70 hover:bg-current/5 transition-all text-left">
                  <NpcAvatar npc={npc} gender={gender} size={40} />
                  <div className="flex-1">
                    <div className="text-sm">{npc.cn}</div>
                    <div className="text-xs opacity-60 italic">{npc.role}</div>
                  </div>
                  <div className="text-xs opacity-60" style={{ fontFamily: 'monospace' }}>
                    {rel > 8 ? '亲近' : rel > 5 ? '熟悉' : rel > 2 ? '认识' : '陌生'}
                  </div>
                </button>
              );
            })}
          </div>
        </div>
      )}

      {actions.length > 0 && (
        <div className="mb-3">
          <div className="text-xs tracking-[0.2em] opacity-60 mb-2" style={{ fontFamily: 'monospace' }}>可以做</div>
          <div className="space-y-2">
            {actions.map((act, i) => (
              <button key={i} onClick={act.onClick} disabled={act.disabled || actionsLeft < 1}
                className="w-full p-3 border border-current/40 hover:border-current hover:bg-current/5 transition-all text-left disabled:opacity-30 disabled:cursor-not-allowed">
                <div className="text-sm">{act.label}</div>
                <div className="text-xs opacity-60 italic">{act.desc}</div>
              </button>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// V6 消息列表样式（WeChat-style）+ 私聊详情。
// ─────────────────────────────────────────────────────────────
//
// 列表项 = 1 个 thread (NPC 1-on-1 / 群聊 / 系统通知折叠)
// 点击 → 进入 ChatDetailView (私聊 bubbles + 底部 contextual 选项)
// 系统通知（uni / l2u / Faculty Office）继续走 flat 列表 fallback。

const ChatListItem = React.memo(function ChatListItem({ avatar, color, name, time, last, badge, onClick, imageUrl }) {
  return (
    <button onClick={onClick}
      className="w-full flex gap-3 px-3 py-2.5 border-b border-current/10 hover:bg-current/5
        transition-colors text-left">
      {imageUrl ? (
        <img src={imageUrl} alt="" className="w-11 h-11 rounded object-cover flex-shrink-0" />
      ) : (
        <div className="w-11 h-11 rounded flex items-center justify-center flex-shrink-0 text-base font-bold text-white"
          style={{ background: color }}>{avatar}</div>
      )}
      <div className="flex-1 min-w-0">
        <div className="flex justify-between items-baseline gap-2">
          <span className="text-sm font-medium truncate">{name}</span>
          <span className="text-[10px] opacity-50 flex-shrink-0"
            style={{ fontFamily: 'monospace' }}>{time}</span>
        </div>
        <div className="flex justify-between items-center gap-2 mt-0.5">
          <span className="text-xs opacity-60 truncate flex-1">{last}</span>
          {badge > 0 && (
            <span className="bg-red-500 text-white text-[10px] font-medium rounded-full
              px-1.5 min-w-[18px] text-center flex-shrink-0">{badge}</span>
          )}
        </div>
      </div>
    </button>
  );
});

function ChatBubble({ role, text, time }) {
  const isYou = role === 'you';
  return (
    <div className={`flex ${isYou ? 'justify-end' : 'justify-start'} mb-2`}>
      <div className={`max-w-[78%] rounded-lg px-3 py-2 text-sm break-words
        ${isYou ? 'bg-amber-300/90 text-stone-900 rounded-tr-sm'
                : 'bg-stone-800/90 text-stone-100 rounded-tl-sm'}`}
        style={{ lineHeight: 1.5 }}>
        {text}
      </div>
    </div>
  );
}

function TypingDots() {
  return (
    <div className="flex justify-start mb-2">
      <div className="bg-stone-800/90 rounded-lg rounded-tl-sm px-3 py-2 flex gap-1">
        <span className="w-1.5 h-1.5 bg-stone-400 rounded-full animate-typing-dot"
          style={{ animationDelay: '0s' }} />
        <span className="w-1.5 h-1.5 bg-stone-400 rounded-full animate-typing-dot"
          style={{ animationDelay: '0.2s' }} />
        <span className="w-1.5 h-1.5 bg-stone-400 rounded-full animate-typing-dot"
          style={{ animationDelay: '0.4s' }} />
      </div>
    </div>
  );
}

function ChatDetailView({
  npcId, npcMeta, thread, options, isTyping, gender, onPickOption, onBack,
}) {
  // 新消息追加时自动滚到底
  const bubblesRef = React.useRef(null);
  React.useEffect(() => {
    const el = bubblesRef.current;
    if (el) el.scrollTop = el.scrollHeight;
  }, [thread?.length, isTyping]);

  const avatarUrl = getNpcImage(npcId, gender);

  return (
    <div className="animate-fadein flex flex-col" style={{ height: 'calc(100dvh - 120px)', maxHeight: 600 }}>
      {/* 顶栏 · back + name */}
      <div className="flex items-center gap-2 pb-3 border-b border-current/20">
        <button onClick={onBack} className="text-base hover:opacity-100 opacity-60 px-1">←</button>
        {avatarUrl ? (
          <img src={avatarUrl} alt="" className="w-8 h-8 rounded object-cover" />
        ) : (
          <div className="w-8 h-8 rounded flex items-center justify-center text-sm font-bold text-white"
            style={{ background: npcMeta.color }}>{npcMeta.avatar}</div>
        )}
        <div className="flex-1 min-w-0">
          <div className="text-sm font-medium">{pronounize(npcMeta.name, gender)}</div>
          <div className="text-[10px] opacity-50">
            {isTyping ? <span className="text-amber-300">正在输入...</span> : npcMeta.tagline}
          </div>
        </div>
      </div>

      {/* 气泡区 */}
      <div ref={bubblesRef} className="flex-1 overflow-y-auto py-3 pr-1">
        {(!thread || thread.length === 0) ? (
          <div className="text-center text-xs opacity-50 italic py-8">
            <div className="mb-2">还没说过话</div>
            <div className="text-[10px] opacity-60">从下方选项开个头</div>
          </div>
        ) : (
          thread.map((m, i) => <ChatBubble key={i} role={m.role} text={pronounize(m.text, gender)} time={m.time} />)
        )}
        {isTyping && <TypingDots />}
      </div>

      {/* 选项区 —— main 选项一列，smalltalk 2 个并排塞最下面。
          NPC 正在输入 → 禁止点击（防 spam）。 */}
      <div className="border-t border-current/20 pt-2 space-y-1.5">
        {options.length === 0 ? (
          <div className="text-xs opacity-40 italic text-center py-2">
            {isTyping ? '（ta 正在输入...）' : '（暂时没什么想说的 · 等 ta 下次开话题）'}
          </div>
        ) : (
          <>
            {/* 主要选项（剧情 / 回复 / 深度问 / 一般问）*/}
            {options.filter(o => o.kind !== 'smalltalk').map(opt => (
              <button key={opt.id} onClick={() => onPickOption(opt)} disabled={isTyping}
                className={`w-full text-left text-sm px-3 py-2 border border-current/30 transition-colors
                  ${isTyping ? 'opacity-40 cursor-not-allowed' : 'hover:border-current hover:bg-current/5'}`}>
                <span className="text-[10px] opacity-50 mr-2 tracking-widest">
                  {opt.kind === 'ask' ? '问 ·' : opt.kind === 'post' ? '发 ·' : '回复 ·'}
                </span>
                {pronounize(opt.label, gender)}
              </button>
            ))}

            {/* Smalltalk 闲聊（每天换 2 个，并排显示）*/}
            {options.some(o => o.kind === 'smalltalk') && (
              <div className="pt-1 mt-1 border-t border-current/10">
                <div className="text-[9px] tracking-[0.2em] opacity-40 mb-1.5 px-1"
                  style={{ fontFamily: 'monospace' }}>· 闲聊 ·</div>
                <div className="grid grid-cols-2 gap-1.5">
                  {options.filter(o => o.kind === 'smalltalk').map(opt => (
                    <button key={opt.id} onClick={() => onPickOption(opt)} disabled={isTyping}
                      className={`text-left text-xs px-2 py-1.5 border border-current/20 transition-colors leading-snug
                        ${isTyping ? 'opacity-40 cursor-not-allowed' : 'hover:border-current/50 hover:bg-current/5'}`}>
                      {pronounize(opt.label, gender)}
                    </button>
                  ))}
                </div>
              </div>
            )}
          </>
        )}
      </div>
    </div>
  );
}

function GroupChatDetailView({
  groupChat, allMembers, options, onPickOption, onBack,
}) {
  const groupBubblesRef = React.useRef(null);
  React.useEffect(() => {
    const el = groupBubblesRef.current;
    if (el) el.scrollTop = el.scrollHeight;
  }, [groupChat.length]);

  return (
    <div className="animate-fadein flex flex-col" style={{ height: 'calc(100dvh - 120px)', maxHeight: 600 }}>
      <div className="flex items-center gap-2 pb-3 border-b border-current/20">
        <button onClick={onBack} className="text-base hover:opacity-100 opacity-60 px-1">←</button>
        <div className="w-8 h-8 rounded flex items-center justify-center text-sm font-bold text-white"
          style={{ background: '#9080b8' }}>群</div>
        <div className="flex-1 min-w-0">
          <div className="text-sm font-medium">伦敦留学生互助 ({allMembers.length})</div>
          <div className="text-[10px] opacity-50">{groupChat.length} 条消息</div>
        </div>
      </div>

      <div ref={groupBubblesRef} className="flex-1 overflow-y-auto py-3 pr-1">
        {groupChat.length === 0 ? (
          <div className="text-center text-xs opacity-50 italic py-8">群里还没人说话。</div>
        ) : (
          groupChat.map(m => {
            if (m.from === '_you') {
              // 你自己发的
              return (
                <div key={m.id} className="flex justify-end mb-2 gap-2">
                  <div className="max-w-[78%] rounded-lg px-3 py-2 text-sm bg-amber-300/90 text-stone-900 rounded-tr-sm">
                    {m.text}
                  </div>
                </div>
              );
            }
            const member = allMembers.find(g => g.id === m.from);
            if (!member) return null;
            return (
              <div key={m.id} className="flex gap-2 items-start mb-2">
                <div className="w-7 h-7 rounded flex items-center justify-center text-[10px] font-medium flex-shrink-0 text-white"
                  style={{ background: member.color }}>{member.avatar}</div>
                <div className="flex-1 min-w-0">
                  <div className="text-[10px] opacity-50 mb-0.5">{member.name} · W{m.week}</div>
                  <div className="text-sm bg-current/5 rounded-lg px-2.5 py-1.5 inline-block max-w-full break-words">
                    {m.text}
                  </div>
                </div>
              </div>
            );
          })
        )}
      </div>

      <div className="border-t border-current/20 pt-2 space-y-1.5">
        {options.length === 0 ? (
          <div className="text-xs opacity-40 italic text-center py-2">
            （这会儿没你能搭的话 · 等群里有动静）
          </div>
        ) : (
          options.map(opt => (
            <button key={opt.id} onClick={() => onPickOption(opt)}
              className="w-full text-left text-sm px-3 py-2 border border-current/30
                hover:border-current hover:bg-current/5 transition-colors">
              <span className="text-[10px] opacity-50 mr-2 tracking-widest">发 ·</span>
              {opt.label}
            </button>
          ))
        )}
      </div>
    </div>
  );
}

export function PhoneView({
  messages, npcRel, chatThreads, chatThreadUnread, seenChatOptions, seenChatOptionsToday,
  flags, week, day,
  stats, gender, storyProgress,
  groupChat, addedStrangers,
  onPickChatOption, onMarkThreadRead,
  onPickGroupOption,
}) {
  // openId: null = 列表 · 'group' = 群聊详情 · npcId = 私聊详情
  const [openId, setOpenId] = useState(null);

  const allGroupMembers = useMemo(() => {
    const strangerSet = new Set(addedStrangers || []);
    return [...GROUP_MEMBERS, ...STRANGERS.filter(s => strangerSet.has(s.id))];
  }, [addedStrangers]);

  // 系统消息 = 非交互 NPC 的 messages
  const systemMsgs = useMemo(() => {
    return (messages || []).filter(m => !INTERACTIVE_NPC_IDS.includes(m.from));
  }, [messages]);

  // ⚠ 所有 hooks 必须在条件 return 之前调用 —— 不能放到列表视图分支里
  // 列表显示规则（"没接触过的人不会出现在消息列表里"）：
  // · 妈妈 / Tom / Mark（合租 flatmates）永远显示 —— 你住一起所以本来就有微信
  // · 其它 NPC：必须 thread 有过消息才显示。
  const npcThreadEntries = useMemo(() => {
    const ALWAYS_VISIBLE = new Set(['mom', 'tom', 'mark']);
    return INTERACTIVE_NPC_IDS
      .map(npcId => {
        const t = chatThreads[npcId] || [];
        const visible = ALWAYS_VISIBLE.has(npcId) || t.length > 0;
        if (!visible) return null;
        const last = t.length ? t[t.length - 1] : null;
        return {
          npcId, last,
          unread: chatThreadUnread[npcId] || 0,
          meta: CHAT_NPC_META[npcId],
          empty: t.length === 0,
        };
      })
      .filter(Boolean)
      .sort((a, b) => {
        if (a.empty && !b.empty) return 1;
        if (!a.empty && b.empty) return -1;
        if (a.empty && b.empty) return 0;
        return (b.last.day || 0) - (a.last.day || 0);
      });
  }, [chatThreads, chatThreadUnread]);

  // ── 详情视图 ──
  // 周阶段：basd on calendar phase (welcome / term / reading / vacation / exam / dissertation)
  const dayOfWeek = ((Date.now() % 7) + 1);  // 占位 — 真正应从 derive 拿
  const weekPhase = week <= 1 ? 'welcome'
    : week <= 12 ? 'autumn'
    : week <= 15 ? 'xmas'
    : week <= 26 ? 'spring'
    : week <= 30 ? 'easter'
    : week <= 33 ? 'revision'
    : week <= 36 ? 'exam'
    : 'dissertation';

  if (openId === 'group') {
    // 找最后一条非玩家发的群消息 —— 玩家可以"接话回复"
    let lastGroupMemberMsg = null;
    for (let i = groupChat.length - 1; i >= 0; i--) {
      if (groupChat[i].from !== '_you') { lastGroupMemberMsg = groupChat[i]; break; }
    }
    const ctx = {
      flags: flags || {}, week, day, seen: seenChatOptions || [],
      stats: stats || {}, gender: gender || null,
      storyProgress: storyProgress || {},
      weekPhase,
      lastGroupMsg: groupChat[groupChat.length - 1],
      lastGroupMemberMsg,
    };
    const opts = getGroupOptions(ctx);
    return (
      <GroupChatDetailView groupChat={groupChat} allMembers={allGroupMembers}
        options={opts}
        onPickOption={(opt) => onPickGroupOption(opt)}
        onBack={() => setOpenId(null)}
      />
    );
  }
  if (openId === '_system') {
    return (
      <div className="animate-fadein flex flex-col" style={{ height: 'calc(100dvh - 120px)', maxHeight: 600 }}>
        <div className="flex items-center gap-2 pb-3 border-b border-current/20">
          <button onClick={() => setOpenId(null)} className="text-base hover:opacity-100 opacity-60 px-1">←</button>
          <div className="w-8 h-8 rounded flex items-center justify-center text-sm font-bold text-white"
            style={{ background: '#5a6068' }}>系</div>
          <div className="flex-1">
            <div className="text-sm font-medium">系统通知</div>
            <div className="text-[10px] opacity-50">学校 · Link2Ur · 客服 · 等</div>
          </div>
        </div>
        <div className="flex-1 overflow-y-auto py-3 pr-1 space-y-2">
          {systemMsgs.length === 0 ? (
            <div className="text-center text-xs opacity-50 italic py-8">没有系统消息</div>
          ) : (
            systemMsgs.slice().reverse().map(m => (
              <div key={m.id} className="p-2.5 border border-current/20 rounded">
                <div className="flex justify-between text-[10px] opacity-60 mb-1">
                  <span>{pronounize(m.fromName, gender)}</span>
                  <span style={{ fontFamily: 'monospace' }}>D{m.day}</span>
                </div>
                <div className="text-sm">{pronounize(m.text, gender)}</div>
              </div>
            ))
          )}
        </div>
      </div>
    );
  }
  if (openId && CHAT_NPC_META[openId]) {
    const npcMeta = CHAT_NPC_META[openId];
    const thread = chatThreads[openId] || [];
    // ctx & opts inline — getChatOptions can be expensive (filters 30+ options)
    // but memoizing requires hoisting; here React's commit phase still skips
    // re-render when openId/flags/thread haven't changed because of the parent state ref.
    const ctx = {
      npcRel: npcRel || {}, flags: flags || {}, week, day,
      stats: stats || {}, gender: gender || null,
      storyProgress: storyProgress || {},
      weekPhase,
      thread, seen: seenChatOptions || [],
      seenToday: seenChatOptionsToday || [],
    };
    const opts = getChatOptions(openId, ctx);
    const isTyping = !!(flags && flags[`_chat_typing_${openId}`]);
    return (
      <ChatDetailView
        npcId={openId} npcMeta={npcMeta} thread={thread}
        options={opts} isTyping={isTyping} gender={gender}
        onPickOption={(opt) => onPickChatOption(openId, opt)}
        onBack={() => setOpenId(null)}
      />
    );
  }

  // ── 列表视图 ──
  // 群聊总在最上 · 系统折叠在最下
  const lastGroup = groupChat.length ? groupChat[groupChat.length - 1] : null;
  const lastGroupMember = lastGroup && allGroupMembers.find(g => g.id === lastGroup.from);
  const lastGroupPreview = lastGroup
    ? (lastGroup.from === '_you' ? `你: ${lastGroup.text}`
       : lastGroupMember ? `${lastGroupMember.name}: ${lastGroup.text}` : lastGroup.text)
    : '（暂无消息）';

  const lastSystem = systemMsgs[systemMsgs.length - 1];

  if (npcThreadEntries.length === 0 && groupChat.length === 0 && systemMsgs.length === 0) {
    return <div className="text-center opacity-50 italic py-12 text-sm">还没有消息</div>;
  }

  return (
    <div className="animate-fadein -mx-1">
      <div className="text-xs tracking-[0.2em] opacity-60 mb-2 px-3"
        style={{ fontFamily: 'monospace' }}>消息</div>

      {/* 群聊置顶 */}
      {groupChat.length > 0 && (
        <ChatListItem
          avatar="群" color="#9080b8"
          name={`伦敦留学生互助 (${allGroupMembers.length})`}
          time={`W${lastGroup.week}`}
          last={lastGroupPreview}
          badge={0}
          onClick={() => setOpenId('group')}
        />
      )}

      {/* NPC threads · 优先用 NPC PNG，没图就 fallback 到 letter+color */}
      {npcThreadEntries.map(e => (
        <ChatListItem key={e.npcId}
          avatar={e.meta.avatar} color={e.meta.color}
          imageUrl={getNpcImage(e.npcId, gender) || undefined}
          name={pronounize(e.meta.name, gender)}
          time={e.empty ? '' : `D${e.last.day}`}
          last={e.empty
            ? <span className="italic opacity-60">点击主动联系...</span>
            : (e.last.role === 'you' ? `你: ${e.last.text}` : e.last.text)
          }
          badge={e.unread}
          onClick={() => {
            setOpenId(e.npcId);
            if (e.unread) onMarkThreadRead(e.npcId);
          }}
        />
      ))}

      {/* 系统通知折叠 */}
      {systemMsgs.length > 0 && (
        <ChatListItem
          avatar="系" color="#5a6068"
          name="系统通知"
          time={`D${lastSystem.day}`}
          last={`${pronounize(lastSystem.fromName, gender)}: ${pronounize(lastSystem.text, gender).slice(0, 40)}`}
          badge={0}
          onClick={() => setOpenId('_system')}
        />
      )}
    </div>
  );
}

// ──────────────────────────────────────────────────────
// JournalView · 手账（合并旧 DiaryView + StoryView）
// 一切是卡片：成就（带插画）/ 决定 / 想家 / 人物 / 学年 / 父母线
// 时序：本周 → 上周 → ... ；底部锚定：人物 / 学年纪事 / 父母线
// ──────────────────────────────────────────────────────

const _journalTagStyle = { fontFamily: 'monospace', fontSize: '9.5px', letterSpacing: '0.1em' };

function MetaTag({ label, value, color }) {
  return (
    <span className="inline-flex items-center gap-1 opacity-70 uppercase"
      style={{ ..._journalTagStyle, color }}>
      {label && <span className="opacity-60">{label}</span>}
      <b className="font-semibold" style={{ color: color || 'currentColor' }}>{value}</b>
    </span>
  );
}

function AchievementCard({ a, onClick }) {
  const meta = ACHIEVEMENT_BY_ID[a.id];
  if (!meta) return null;
  const tier = TIER_META[meta.tier];
  const img = getAchievementImage(a.id);
  const isLegendary = meta.tier === 'legendary';
  return (
    <button onClick={onClick} type="button"
      className="block w-full text-left border p-3 rounded-sm transition-all hover:border-current/70 hover:-translate-y-px focus:outline-none focus:ring-2 focus:ring-current/30"
      style={{ borderColor: tier.borderColor, background: tier.photoBg + '14' }}>
      <div className="flex items-start gap-3">
        <div className="flex-shrink-0 w-14 h-14 rounded-sm overflow-hidden flex items-center justify-center text-3xl"
          style={{ background: tier.photoBg }}>
          {img
            ? <img src={img} alt="" className="w-full h-full object-cover" />
            : <span>{meta.icon}</span>}
        </div>
        <div className="flex-1 min-w-0">
          <div className="inline-block px-1.5 py-0.5 rounded-sm mb-1"
            style={{ ..._journalTagStyle, background: isLegendary ? tier.accent : '#00000040', color: isLegendary ? '#1a1612' : tier.accent }}>
            {tier.label} · 成就
          </div>
          <div className="text-sm font-medium leading-tight">{meta.title}</div>
          <div className="text-xs opacity-70 mt-1 leading-relaxed">{meta.desc}</div>
        </div>
        <div className="text-xs opacity-40 flex-shrink-0 self-center pl-1">→</div>
      </div>
      <div className="flex flex-wrap gap-3 mt-3 pt-2.5 border-t border-current/15">
        <MetaTag label="W" value={a.week ?? '?'} />
        <MetaTag value={meta.icon} />
        <span className="ml-auto opacity-50" style={_journalTagStyle}>点击查看卡片</span>
      </div>
    </button>
  );
}

function DecisionCard({ c }) {
  return (
    <div className="border border-amber-300/40 bg-amber-300/5 p-3 rounded-sm">
      <div className="opacity-60 uppercase mb-1" style={_journalTagStyle}>◆ DECISION · W{c.week ?? '?'}</div>
      <div className="text-sm font-medium leading-snug mb-1.5"
        style={{ color: '#d4b070', fontFamily: '"Noto Serif SC", serif' }}>
        "{c.title}"
      </div>
      <div className="text-xs opacity-75 italic leading-relaxed whitespace-pre-line">
        {c.line}
      </div>
    </div>
  );
}

function MemoryCard({ entry, kind }) {
  const palette = {
    dream:     { color: '#c8b8e0', icon: '☾', label: '梦' },
    insomnia:  { color: '#a8a09c', icon: '☾', label: '失眠' },
    nostalgia: { color: '#e8c8c0', icon: '🏮', label: '想家' },
  }[kind] || palette.dream;
  return (
    <details className="border border-current/20 p-3 rounded-sm group">
      <summary className="cursor-pointer flex items-center gap-2 text-sm">
        <span style={{ color: palette.color }}>{palette.icon}</span>
        <span className="flex-1 leading-snug">{entry.title}</span>
        <span className="opacity-50" style={_journalTagStyle}>{palette.label}</span>
      </summary>
      <div className="mt-2.5 pl-5 text-sm opacity-85 italic whitespace-pre-line border-l-2 border-current/15"
        style={{ lineHeight: '1.9', color: palette.color }}>
        {entry.body}
      </div>
    </details>
  );
}

function NpcCard({ line, npc, progress, gender }) {
  const total = line.chapters.length;
  const completed = progress >= total;
  const lastChapter = line.chapters[Math.min(progress, total) - 1];
  return (
    <div className="border border-current/30 p-3 rounded-sm">
      <div className="flex items-center gap-3">
        <NpcAvatar npc={npc} gender={gender} size={44} />
        <div className="flex-1 min-w-0">
          <div className="flex justify-between items-baseline">
            <div className="text-sm font-medium">{line.name}</div>
            <div className="opacity-60" style={_journalTagStyle}>
              CH {progress} / {total}{completed && ' ✓'}
            </div>
          </div>
          <div className="flex gap-1 mt-1.5">
            {line.chapters.map((_, i) => (
              <div key={i} className={`flex-1 h-0.5 ${i < progress ? 'bg-current' : 'bg-current/20'}`} />
            ))}
          </div>
          {lastChapter && (
            <div className="text-xs opacity-60 italic mt-1.5">"{lastChapter.title}"</div>
          )}
        </div>
      </div>
    </div>
  );
}

function ParentsCard({ chapter, declined }) {
  const summaries = [
    '妈妈还没问起来过。',
    '妈妈问了。等春节。',
    '妈妈在练 "How are you"。',
    '他们在伦敦。',
    '他们在你的伦敦。',
    '他们走了。',
  ];
  return (
    <div className="border border-amber-300/40 bg-amber-300/5 p-3 rounded-sm">
      <div className="flex justify-between items-baseline mb-1.5">
        <div className="uppercase opacity-60" style={_journalTagStyle}>🇨🇳 父母线</div>
        <div className="opacity-60" style={_journalTagStyle}>CH {chapter} / 5</div>
      </div>
      {declined ? (
        <div className="text-xs opacity-70 italic">你拒绝了他们这次来。后面再没机会。</div>
      ) : (
        <>
          <div className="flex gap-1 mb-2">
            {[1,2,3,4,5].map(i => (
              <div key={i} className={`flex-1 h-0.5 ${i <= chapter ? 'bg-amber-300/70' : 'bg-current/20'}`} />
            ))}
          </div>
          <div className="text-sm italic" style={{ color: '#d4b070' }}>
            {summaries[Math.min(chapter, 5)]}
          </div>
        </>
      )}
    </div>
  );
}

function TermCard({ week, weekInfo, monthAttendance, examResults }) {
  const totalWeeks = 52;
  const phaseText = weekInfo?.cn || '在伦敦';
  return (
    <div className="border border-current/30 p-3 rounded-sm">
      <div className="flex justify-between items-baseline mb-2">
        <div className="uppercase opacity-60" style={_journalTagStyle}>学年纪事</div>
        <div className="opacity-60" style={_journalTagStyle}>W {week} / {totalWeeks}</div>
      </div>
      <div className="text-sm font-medium mb-2">{phaseText}</div>
      <div className="flex gap-[2px] mb-3">
        {Array.from({ length: totalWeeks }).map((_, i) => (
          <div key={i} className={`flex-1 h-1 ${i < week ? 'bg-current/70' : 'bg-current/15'}`} />
        ))}
      </div>
      {monthAttendance?.length > 0 && (
        <div className="mb-2">
          <div className="text-xs opacity-60 mb-1">月度出勤</div>
          <div className="flex gap-1">
            {monthAttendance.map((m, i) => {
              const c = m.rate >= 80 ? '#a0c890' : m.rate >= 70 ? '#d4b070' : m.rate >= 60 ? '#d49060' : '#c86060';
              return (
                <div key={i} className="flex-1 text-center">
                  <div className="text-xs" style={{ color: c, fontFamily: 'monospace' }}>{m.rate}%</div>
                  <div className="h-1 mt-0.5" style={{ background: c }} />
                  <div className="opacity-50 mt-0.5" style={_journalTagStyle}>M{m.month}</div>
                </div>
              );
            })}
          </div>
        </div>
      )}
      {Object.keys(examResults || {}).length > 0 && (
        <div>
          <div className="text-xs opacity-60 mb-1">考试成绩</div>
          <div className="space-y-0.5 text-xs">
            {Object.entries(examResults).map(([id, score]) => {
              const exam = EXAM_PAPERS.find(e => e.id === id);
              const c = score >= 70 ? '#a0c890' : score >= 50 ? '#d4b070' : '#c86060';
              return (
                <div key={id} className="flex justify-between" style={{ fontFamily: 'monospace' }}>
                  <span className="opacity-80">{exam?.cn || id}</span>
                  <span style={{ color: c }}>{score}%</span>
                </div>
              );
            })}
          </div>
        </div>
      )}
    </div>
  );
}

function WeekHeader({ week, label }) {
  return (
    <div className="flex items-center gap-2 mt-3 mb-2">
      <div className="flex-1 h-px bg-current/20" />
      <div className="uppercase opacity-60 px-1" style={_journalTagStyle}>
        WEEK {week}{label ? ` · ${label}` : ''}
      </div>
      <div className="flex-1 h-px bg-current/20" />
    </div>
  );
}

function SectionHeader({ children }) {
  return (
    <div className="uppercase opacity-60 mt-4 mb-2 px-0.5" style={_journalTagStyle}>
      {children}
    </div>
  );
}

export function JournalView({
  diaryChoices, unlockedAchievements,
  seenDreams, seenInsomnia, seenNostalgia,
  storyProgress, npcRel,
  monthAttendance, examResults,
  parentsChapter, flags,
  gender, gameState, week, weekInfo,
}) {
  const [filter, setFilter] = useState('all');
  const [openCard, setOpenCard] = useState(null);     // {id, week} 触发 AchievementCardModal
  const [wrappedOpen, setWrappedOpen] = useState(false);

  // ── 时序：成就 + 决定（都有 week）──
  const achTimeline = useMemo(() =>
    (unlockedAchievements || []).map(a => ({ kind: 'ach', week: a.week ?? 0, a }))
  , [unlockedAchievements]);
  const choiceTimeline = useMemo(() =>
    (diaryChoices || []).map(c => ({ kind: 'choice', week: c.week ?? 0, c }))
  , [diaryChoices]);
  const timeline = useMemo(() =>
    [...achTimeline, ...choiceTimeline].sort((x, y) => (y.week || 0) - (x.week || 0))
  , [achTimeline, choiceTimeline]);

  // ── 反思：dream / insomnia / nostalgia ──
  const dreamEntries = useMemo(() =>
    (seenDreams || []).map(id => DREAMS.find(d => d.id === id)).filter(Boolean)
  , [seenDreams]);
  const insomniaEntries = useMemo(() =>
    (seenInsomnia || []).map(id => INSOMNIA_THOUGHTS.find(i => i.id === id)).filter(Boolean)
  , [seenInsomnia]);
  const nostalgiaEntries = useMemo(() =>
    (seenNostalgia || []).map(id => NOSTALGIA_MOMENTS.find(n => n.id === id)).filter(Boolean)
  , [seenNostalgia]);
  const memoryTotal = dreamEntries.length + insomniaEntries.length + nostalgiaEntries.length;

  // ── 人物：已遇见的 storylines ──
  const activeLines = useMemo(() =>
    Object.values(STORYLINES).filter(line => (storyProgress?.[line.id] || 0) > 0)
  , [storyProgress]);

  const totalCards = (unlockedAchievements?.length || 0) + (diaryChoices?.length || 0) + memoryTotal;
  const showParentsLine = parentsChapter > 0 || flags?.parents_coming || flags?.parents_declined;

  // 时序按 week 分组（最近优先）
  const timelineByWeek = useMemo(() => {
    const groups = {};
    for (const item of timeline) {
      const w = item.week || 0;
      if (!groups[w]) groups[w] = [];
      groups[w].push(item);
    }
    return Object.entries(groups)
      .map(([w, items]) => ({ week: parseInt(w, 10), items }))
      .sort((a, b) => b.week - a.week);
  }, [timeline]);

  const diaryCover = getMiscImage('diary-cover');
  const emptyState = totalCards === 0 && activeLines.length === 0 && !showParentsLine;

  if (emptyState) {
    return (
      <div className="animate-fadein text-center py-12">
        <div className="text-sm opacity-50 italic mb-3">手账还是空的。</div>
        <div className="text-xs opacity-40 italic" style={{ lineHeight: '1.8' }}>
          这本子会自己写满。<br/>
          每一个决定、每一次想家、每一个解锁的成就，<br/>
          都会变成一张卡片。
        </div>
      </div>
    );
  }

  const tabs = [
    { id: 'all',     label: '全部',  count: totalCards },
    { id: 'ach',     label: '成就',  count: unlockedAchievements?.length || 0 },
    { id: 'choice',  label: '决定',  count: diaryChoices?.length || 0 },
    { id: 'memory',  label: '想家',  count: memoryTotal },
    { id: 'people',  label: '人物',  count: activeLines.length },
    { id: 'term',    label: '学年',  count: (showParentsLine ? 1 : 0) + (monthAttendance?.length || 0) },
  ];

  return (
    <div className="animate-fadein">
      {/* 封面 */}
      {diaryCover && (
        <div className="relative w-full mb-3 -mx-1 overflow-hidden" style={{ aspectRatio: '5 / 2' }}>
          <img src={diaryCover} alt="" className="w-full h-full object-cover" />
          <div className="absolute inset-0"
            style={{ background: 'linear-gradient(180deg, transparent 30%, rgba(10,8,6,0.92) 100%)' }} />
          <div className="absolute left-3 bottom-2 right-3">
            <div className="uppercase opacity-70" style={_journalTagStyle}>VOLUME I · WEEK {week}</div>
            <div className="text-2xl font-medium tracking-tight"
              style={{ fontFamily: '"Noto Serif SC", serif' }}>手账</div>
          </div>
        </div>
      )}
      {!diaryCover && (
        <div className="mb-3">
          <div className="uppercase opacity-60" style={_journalTagStyle}>VOLUME I · WEEK {week}</div>
          <div className="text-2xl font-medium tracking-tight"
            style={{ fontFamily: '"Noto Serif SC", serif' }}>手账</div>
        </div>
      )}

      {/* 摘要行 + 海报导出按钮（点击进 wrapped 预览，预览里再下载/分享）*/}
      <div className="flex justify-between items-center mb-3 px-0.5">
        <div className="text-xs opacity-70" style={{ lineHeight: 1.6 }}>
          <b className="font-semibold">{totalCards}</b> 张卡片 · 在伦敦的第 <b className="font-semibold">{week}</b> 周
        </div>
        {gameState && (unlockedAchievements?.length || 0) > 0 && (
          <button onClick={() => setWrappedOpen(true)}
            className="px-2.5 py-1 border text-xs tracking-[0.15em] transition-colors flex items-center gap-1"
            style={{ borderColor: '#d4b070a0', color: '#d4b070', background: '#d4b07012' }}
            title="生成 1080×1920 朋友圈竖版海报">
            📸 <span>导出海报</span>
          </button>
        )}
      </div>

      {/* 筛选 tabs */}
      <div className="flex gap-0 border-t border-b border-current/20 mb-3 overflow-x-auto" style={{ scrollbarWidth: 'none' }}>
        {tabs.map(t => (
          <button key={t.id} onClick={() => setFilter(t.id)}
            className={`py-2.5 mr-4 text-sm whitespace-nowrap flex-shrink-0 transition-colors
              ${filter === t.id ? 'opacity-100 border-b-2 border-current -mb-px font-medium' : 'opacity-50 hover:opacity-80'}`}>
            {t.label}<span className="ml-1 opacity-70" style={_journalTagStyle}>{t.count}</span>
          </button>
        ))}
      </div>

      <div className="space-y-2 max-h-[58vh] overflow-y-auto pr-1">

        {/* ─── 全部 / 成就 / 决定 共用时序流 ─── */}
        {(filter === 'all' || filter === 'ach' || filter === 'choice') && timelineByWeek.map(({ week: w, items }) => {
          const filtered = filter === 'ach' ? items.filter(i => i.kind === 'ach')
            : filter === 'choice' ? items.filter(i => i.kind === 'choice')
            : items;
          if (filtered.length === 0) return null;
          return (
            <React.Fragment key={w}>
              <WeekHeader week={w} />
              {filtered.map((item, i) => item.kind === 'ach'
                ? <AchievementCard key={`a-${w}-${item.a.id}`} a={item.a}
                    onClick={() => setOpenCard({ id: item.a.id, week: item.a.week,
                      ...(ACHIEVEMENT_BY_ID[item.a.id] || {}) })} />
                : <DecisionCard key={`c-${w}-${i}`} c={item.c} />
              )}
            </React.Fragment>
          );
        })}

        {/* ─── 想家 ─── */}
        {(filter === 'all' || filter === 'memory') && memoryTotal > 0 && (
          <>
            <SectionHeader>想家 · {memoryTotal}</SectionHeader>
            {nostalgiaEntries.map(e => <MemoryCard key={`n-${e.id}`} entry={e} kind="nostalgia" />)}
            {dreamEntries.map(e => <MemoryCard key={`d-${e.id}`} entry={e} kind="dream" />)}
            {insomniaEntries.map(e => <MemoryCard key={`i-${e.id}`} entry={e} kind="insomnia" />)}
          </>
        )}

        {/* ─── 人物 ─── */}
        {(filter === 'all' || filter === 'people') && activeLines.length > 0 && (
          <>
            <SectionHeader>人物 · {activeLines.length}</SectionHeader>
            {activeLines.map(line => (
              <NpcCard key={line.id} line={line} npc={NPCS[line.npc]}
                progress={storyProgress[line.id] || 0} gender={gender} />
            ))}
          </>
        )}

        {/* ─── 学年 + 父母线 ─── */}
        {(filter === 'all' || filter === 'term') && (
          <>
            <SectionHeader>学年纪事</SectionHeader>
            <TermCard week={week} weekInfo={weekInfo}
              monthAttendance={monthAttendance} examResults={examResults} />
            {showParentsLine && (
              <ParentsCard chapter={parentsChapter} declined={!!flags?.parents_declined} />
            )}
          </>
        )}

        {/* 各 filter 空态 */}
        {filter === 'ach' && (unlockedAchievements?.length || 0) === 0 && (
          <div className="text-xs opacity-50 italic text-center py-6">还没解锁成就。多去体验。</div>
        )}
        {filter === 'choice' && (diaryChoices?.length || 0) === 0 && (
          <div className="text-xs opacity-50 italic text-center py-6">还没做过值得记的决定。</div>
        )}
        {filter === 'memory' && memoryTotal === 0 && (
          <div className="text-xs opacity-50 italic text-center py-6">还没失眠过 · 还没想家过。</div>
        )}
        {filter === 'people' && activeLines.length === 0 && (
          <div className="text-xs opacity-50 italic text-center py-6">还没遇到谁。多去几个地方、和人说话。</div>
        )}
      </div>

      {openCard && (
        <AchievementCardModal achievement={openCard} gender={gender}
          onClose={() => setOpenCard(null)} />
      )}
      {wrappedOpen && gameState && (
        <WrappedPosterModal gameState={gameState}
          onClose={() => setWrappedOpen(false)} />
      )}
    </div>
  );
}

// (旧 GroupChatView 已并入 PhoneView 的群聊详情，删除以避免歧义)
