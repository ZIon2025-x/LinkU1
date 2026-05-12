import React, { useState } from 'react';
import { audio } from '../engine/audio.js';
import {
  NPCS, STORYLINES, LOCATIONS, EXAM_PAPERS, DISSERTATION_TOPICS, WEATHERS,
  PLANE_SCENE, HEATHROW_INTRO, TRANSPORT_OPTIONS, APARTMENT_ARRIVAL,
} from '../data/index.js';
import { TabBtn, MiniStat } from './Atoms.jsx';
import { MapView, PhoneView, JournalView } from './Views.jsx';
import { Link2UrView } from './Link2UrView.jsx';
import { NpcAvatar } from './NpcAvatar.jsx';
import { getLocationImage, getSceneImage, getMiscImage } from '../engine/imageRegistry.js';

export function PlaneScreen({ onContinue }) {
  const banner = getSceneImage('plane');
  return (
    <div className="text-left pt-8 pb-8 max-w-md mx-auto animate-fadein-slow">
      {banner && (
        <div className="relative w-full mb-6 -mx-4" style={{ aspectRatio: '16 / 9' }}>
          <img src={banner} alt="" className="w-full h-full object-cover" />
          <div className="absolute inset-0"
            style={{ background: 'linear-gradient(180deg, transparent 60%, rgba(10,8,6,1) 100%)' }} />
        </div>
      )}
      <div className="text-xs tracking-[0.4em] opacity-50 mb-2" style={{ fontFamily: 'monospace' }}>
        {PLANE_SCENE.subtitle}
      </div>
      <h2 className="text-3xl font-light mb-6">{PLANE_SCENE.title}</h2>
      <div className="space-y-4 text-sm leading-relaxed opacity-90" style={{ lineHeight: '1.95' }}>
        {PLANE_SCENE.body.map((p, i) => <p key={i}>{p}</p>)}
      </div>
      <button onClick={onContinue}
        className="mt-10 w-full py-3 border border-current/60 hover:bg-current hover:text-black transition-colors duration-500 tracking-[0.3em] text-sm">
        {PLANE_SCENE.cta} →
      </button>
    </div>
  );
}

export function ArrivalScreen({ wallet, onChoose }) {
  const [chosen, setChosen] = useState(null);
  const [phase, setPhase] = useState('transport');

  if (chosen && phase === 'transport') {
    return (
      <div className="text-left pt-8 pb-8 max-w-md mx-auto animate-fadein-slow">
        <div className="text-xs tracking-[0.4em] opacity-50 mb-2" style={{ fontFamily: 'monospace' }}>
          {chosen.emoji} {chosen.label.toUpperCase()}
        </div>
        <div className="border-l-2 border-amber-300/60 pl-4 py-2 mb-6 italic opacity-90 text-sm whitespace-pre-line"
          style={{ lineHeight: '1.95' }}>
          {chosen.feedback}
        </div>
        <button onClick={() => setPhase('apartment')}
          className="w-full py-3 border border-current/60 hover:bg-current hover:text-black transition-colors duration-500 tracking-[0.3em] text-sm">
          走进公寓门 →
        </button>
      </div>
    );
  }

  if (chosen && phase === 'apartment') {
    const apartmentBanner = getSceneImage('apartment_keys');
    return (
      <div className="text-left pt-8 pb-8 max-w-md mx-auto animate-fadein-slow">
        {apartmentBanner && (
          <div className="relative w-full mb-6" style={{ aspectRatio: '16 / 9' }}>
            <img src={apartmentBanner} alt="" className="w-full h-full object-cover" />
            <div className="absolute inset-0"
              style={{ background: 'linear-gradient(180deg, transparent 60%, rgba(10,8,6,1) 100%)' }} />
          </div>
        )}
        <div className="text-xs tracking-[0.4em] opacity-50 mb-2" style={{ fontFamily: 'monospace' }}>
          {APARTMENT_ARRIVAL.subtitle}
        </div>
        <h2 className="text-3xl font-light mb-6">{APARTMENT_ARRIVAL.title}</h2>
        <div className="space-y-4 text-sm leading-relaxed opacity-90 mb-8" style={{ lineHeight: '1.95' }}>
          {APARTMENT_ARRIVAL.body.map((p, i) => <p key={i}>{p}</p>)}
        </div>
        <button onClick={() => setPhase('credits')}
          className="w-full py-3 border border-current/60 hover:bg-current hover:text-black transition-colors duration-500 tracking-[0.3em] text-sm">
          {APARTMENT_ARRIVAL.cta}
        </button>
      </div>
    );
  }

  if (chosen && phase === 'credits') {
    return (
      <div className="text-center pt-16 pb-8 max-w-md mx-auto animate-fadein-slow">
        <div className="text-xs tracking-[0.4em] opacity-50 mb-12" style={{ fontFamily: 'monospace' }}>
          PRESENTED BY · 鸣谢
        </div>
        <div className="mb-2 flex items-center justify-center gap-3">
          <div className="w-10 h-10 rounded flex items-center justify-center text-xl font-bold"
            style={{ background: '#007AFF', color: 'white' }}>L</div>
          <div className="text-3xl font-light tracking-wide" style={{ color: '#007AFF' }}>Link2Ur</div>
        </div>
        <div className="text-sm opacity-70 italic mb-1">留学生互助平台</div>
        <div className="text-xs opacity-40 mb-12" style={{ fontFamily: 'monospace' }}>link2ur.com</div>
        <div className="max-w-xs mx-auto text-xs opacity-60 italic leading-relaxed" style={{ lineHeight: '1.9' }}>
          本作的灵感来自留学生互助平台 Link2Ur ——<br/>
          也是这群孩子真的在用的 app。
        </div>
        <div className="text-xs opacity-30 mt-6" style={{ fontFamily: 'monospace' }}>♥</div>
        <button onClick={() => onChoose(chosen)}
          className="mt-12 px-12 py-3 border border-current/60 hover:bg-current hover:text-black transition-colors duration-500 tracking-[0.3em] text-sm">
          开始这一年 →
        </button>
      </div>
    );
  }

  const heathrowBanner = getSceneImage('heathrow_arrival');
  return (
    <div className="text-left pt-8 pb-8 max-w-md mx-auto animate-fadein-slow">
      {heathrowBanner && (
        <div className="relative w-full mb-6" style={{ aspectRatio: '16 / 9' }}>
          <img src={heathrowBanner} alt="" className="w-full h-full object-cover" />
          <div className="absolute inset-0"
            style={{ background: 'linear-gradient(180deg, transparent 60%, rgba(10,8,6,1) 100%)' }} />
        </div>
      )}
      <div className="text-xs tracking-[0.4em] opacity-50 mb-2" style={{ fontFamily: 'monospace' }}>
        {HEATHROW_INTRO.subtitle}
      </div>
      <h2 className="text-3xl font-light mb-6">{HEATHROW_INTRO.title}</h2>
      <div className="space-y-4 text-sm leading-relaxed opacity-90 mb-8" style={{ lineHeight: '1.95' }}>
        {HEATHROW_INTRO.body.map((p, i) => <p key={i}>{p}</p>)}
      </div>

      <div className="text-xs tracking-[0.2em] opacity-60 mb-2" style={{ fontFamily: 'monospace' }}>
        怎么回公寓？
      </div>
      <div className="space-y-2">
        {TRANSPORT_OPTIONS.map(opt => {
          const cantAfford = wallet < opt.cost;
          return (
            <button key={opt.id}
              onClick={() => !cantAfford && setChosen(opt)}
              disabled={cantAfford}
              className={`w-full text-left p-3 border transition-all ${cantAfford
                ? 'border-current/20 opacity-30 cursor-not-allowed'
                : 'border-current/40 hover:border-current hover:bg-current/5'}`}>
              <div className="flex justify-between items-baseline">
                <span className="text-sm">
                  <span className="mr-2">{opt.emoji}</span>{opt.label}
                </span>
                <span className="text-xs" style={{ fontFamily: 'monospace', color: '#d4b070' }}>
                  £{opt.cost}
                </span>
              </div>
              <div className="text-xs opacity-60 italic mt-1" style={{ fontFamily: 'monospace' }}>
                {opt.time}
              </div>
              <div className="text-xs opacity-70 mt-1">{opt.desc}</div>
            </button>
          );
        })}
      </div>
    </div>
  );
}

export function IntroScreen({ onStart }) {
  const logo = getMiscImage('logo');
  return (
    <div className="text-center pt-12 pb-8 animate-fadein">
      <div className="text-xs tracking-[0.4em] opacity-50 mb-6" style={{ fontFamily: 'monospace' }}>A STUDY ABROAD RPG · V10</div>
      {logo ? (
        <img src={logo} alt="異鄉" className="mx-auto mb-2 max-h-40 object-contain" />
      ) : (
        <h1 className="text-7xl font-light mb-2" style={{ letterSpacing: '0.05em' }}>異 鄉</h1>
      )}
      <div className="text-sm tracking-[0.3em] opacity-60 mb-12 italic">somewhere else</div>
      <div className="max-w-md mx-auto text-left space-y-3 text-sm leading-relaxed opacity-85" style={{ lineHeight: '1.9' }}>
        <p>九月，伦敦。两个箱子，一张录取通知书。</p>
        <p>52 周。10 个地点。5 个朋友。</p>
        <p>秋学期 → 圣诞 → 春学期 → 复活节 → 期末考 → 论文。</p>
        <p>每天 3 个行动。这一年怎么过，由你决定。</p>
        <p className="opacity-60 italic">这次，你来掌控故事。</p>
      </div>
      <div className="max-w-sm mx-auto mt-10 grid grid-cols-2 gap-2 text-xs opacity-60" style={{ fontFamily: 'monospace' }}>
        <div className="border border-amber-300/40 p-2" style={{ color: '#d4b070' }}>🇨🇳 父母来伦敦</div>
        <div className="border border-current/30 p-2">📔 心理日记</div>
        <div className="border border-current/30 p-2">⚠️ 4:38 AM 危机</div>
        <div className="border border-current/30 p-2">📮 结局回响</div>
      </div>
      <button onClick={onStart} className="mt-10 px-12 py-3 border border-current hover:bg-current hover:text-black transition-colors duration-500 tracking-[0.3em] text-sm">
        BEGIN
      </button>
      <div className="mt-4 text-xs opacity-40 italic">建议开启声音 🔊</div>
    </div>
  );
}

export function PlayingScreen(props) {
  const { day, week, dayOfWeek, stats, actionsLeft, weekInfo, tab, setTab,
    currentLocation, setCurrentLocation, onGoToLocation,
    onAttendClass, onWorkShift, onRestAtFlat, onCallHome, onTalkNPC,
    onStudyAtFlat, onStudyAtLibrary, onStudyAtUni, onActivity,
    onWriteDissertation, dissertationProgress, dissertationTopic,
    onEndDay, messages, unreadMessages, onReadMessages, npcRel,
    attendanceRate, currentMonthRate, classesAttendedThisWeek, storyProgress,
    travelMode, onStartTravel, monthAttendance, examResults,
    weather, groupChat, unreadGroup, onReadGroup, addedStrangers,
    seenDreams, seenInsomnia, seenNostalgia, diaryChoices,
    unlockedAchievements, gender,
    parentsChapter, flags,
    chatThreads, chatThreadUnread, seenChatOptions, seenChatOptionsToday,
    onPickChatOption, onMarkThreadRead, onPickGroupOption,
    onTriggerPret, onTriggerEssay, onTriggerMatch,
    onOpenBag,
    link2urProps } = props;

  const dayNames = ['一', '二', '三', '四', '五', '六', '日'];
  const attendanceColor = attendanceRate >= 80 ? '#a0c890' : attendanceRate >= 70 ? '#d4b070' : attendanceRate >= 50 ? '#d49060' : '#c86060';
  const diaryTotal = (seenDreams?.length || 0) + (seenInsomnia?.length || 0) + (seenNostalgia?.length || 0) + (diaryChoices?.length || 0);

  // 周类型颜色和提示
  const weekColor = {
    welcome: '#d4b070', term: '#a0c890', reading: '#a0a0c8',
    vacation_xmas: '#c89090', vacation_easter: '#c890a8',
    revision: '#d4a574', exam: '#c86060', dissertation: '#9080b8',
  }[weekInfo?.type || 'term'];

  const weekTypeIcon = {
    welcome: '👋', term: '📚', reading: '📖',
    vacation_xmas: '🎄', vacation_easter: '🐣',
    revision: '☕', exam: '✍️', dissertation: '📝',
  }[weekInfo?.type || 'term'];

  return (
    <div className="animate-fadein flex flex-col h-[100dvh] -mx-3 -my-6">
      {/* === A: HEADER === */}
      <div className="flex-shrink-0 px-3 pt-[env(safe-area-inset-top)]">
      <button
        type="button"
        onClick={() => { audio.click(); onOpenBag(); }}
        className="w-full text-left pt-2 pb-1.5 border-b border-current/20
                   active:bg-current/5 transition-colors"
      >
        {/* row 1: pill + ACTIONS dots */}
        <div className="flex justify-between items-center">
          <span className="px-2.5 py-0.5 rounded-full text-[10px] font-mono tracking-wider"
                style={{
                  background: 'rgba(212,176,112,0.15)',
                  border: '1px solid rgba(212,176,112,0.4)',
                  color: '#d4b070',
                }}>
            D{day} · W{week} · 周{dayNames[dayOfWeek-1]}
            {weekInfo && <> · {weekTypeIcon} {weekInfo.cn}</>}
            {weather && <> · {WEATHERS[weather]?.emoji}</>}
            {weekInfo?.deadline && <span className="ml-1.5 text-orange-300">⏰</span>}
          </span>
          <div className="flex gap-1">
            {[...Array(3)].map((_, i) => (
              <div key={i} className={`w-2 h-2 rounded-full ${
                i < actionsLeft ? 'bg-current/80' : 'bg-current/15 border border-current/30'
              }`} />
            ))}
          </div>
        </div>

        {/* row 2: 4 stats inline */}
        <div className="mt-1.5 flex justify-between text-[11px]" style={{ fontFamily: 'monospace' }}>
          {(() => {
            const a = stats.academic;
            const aColor = a >= 70 ? '#22c55e' : a >= 50 ? undefined : a >= 35 ? '#f97316' : '#ef4444';
            const w = stats.wallet;
            const wColor = w < 0 ? '#ef4444' : w < 150 ? '#f97316' : w < 400 ? '#eab308' : w < 800 ? undefined : '#22c55e';
            const e = stats.energy;
            const eText = e >= 75 ? '充沛' : e >= 50 ? '还行' : e >= 25 ? '疲惫' : e >= 10 ? '虚脱' : '濒崩';
            const eColor = e >= 75 ? '#22c55e' : e >= 50 ? undefined : e >= 25 ? '#eab308' : e >= 10 ? '#f97316' : '#ef4444';
            const s = props.gameState?.stress ?? 25;
            const sText = s >= 95 ? '崩盘' : s >= 85 ? '濒崩' : s >= 75 ? '紧绷' : s >= 60 ? '有点累' : s >= 30 ? '能扛' : '平静';
            const sColor = s >= 85 ? '#ef4444' : s >= 75 ? '#f97316' : s >= 60 ? '#eab308' : s >= 30 ? undefined : '#22c55e';
            return (
              <>
                <span>📚 <span style={{ color: aColor }}>{a}%</span></span>
                <span style={{ color: wColor }}>💰 £{w}</span>
                <span>💪 <span style={{ color: eColor }}>{eText}</span></span>
                <span>🧠 <span style={{ color: sColor }}>{sText}</span></span>
              </>
            );
          })()}
        </div>

        {/* row 3: tap hint */}
        <div className="text-center text-[9px] opacity-40 mt-1" style={{ fontFamily: 'monospace' }}>
          ▼ 点击查看完整状态
        </div>
      </button>
      </div>{/* === /A: HEADER === */}

      {/* === B: CONTENT === */}
      <div className="flex-1 overflow-y-auto px-3">
      {tab === 'map' && (
        <MapView locations={LOCATIONS} actionsLeft={actionsLeft} onGoToLocation={onGoToLocation}
          currentLocation={currentLocation} setCurrentLocation={setCurrentLocation}
          onAttendClass={onAttendClass} onWorkShift={onWorkShift} onRestAtFlat={onRestAtFlat}
          onStudyAtFlat={onStudyAtFlat} onStudyAtLibrary={onStudyAtLibrary} onStudyAtUni={onStudyAtUni}
          onActivity={onActivity}
          onCallHome={onCallHome} onTalkNPC={onTalkNPC}
          onWriteDissertation={onWriteDissertation}
          weekInfo={weekInfo}
          dissertationTopic={dissertationTopic}
          npcRel={npcRel} day={day} week={week} stats={stats} onStartTravel={onStartTravel}
          onTriggerPret={onTriggerPret}
          onTriggerEssay={onTriggerEssay}
          onTriggerMatch={onTriggerMatch}
          gender={gender}
        />
      )}
      {tab === 'phone' && (
        <PhoneView
          messages={messages} npcRel={npcRel}
          chatThreads={chatThreads || {}} chatThreadUnread={chatThreadUnread || {}}
          seenChatOptions={seenChatOptions || []} seenChatOptionsToday={seenChatOptionsToday || []}
          flags={flags || {}} week={week} day={day}
          stats={stats} gender={gender} storyProgress={storyProgress}
          groupChat={groupChat || []} addedStrangers={addedStrangers || []}
          onPickChatOption={onPickChatOption} onMarkThreadRead={onMarkThreadRead}
          onPickGroupOption={onPickGroupOption}
        />
      )}
      {tab === 'link2ur' && link2urProps && (
        <Link2UrView {...link2urProps} />
      )}
      {tab === 'journal' && (
        <JournalView
          diaryChoices={diaryChoices}
          unlockedAchievements={unlockedAchievements}
          seenDreams={seenDreams} seenInsomnia={seenInsomnia} seenNostalgia={seenNostalgia}
          storyProgress={storyProgress} npcRel={npcRel}
          monthAttendance={monthAttendance} examResults={examResults}
          parentsChapter={parentsChapter} flags={flags}
          gender={gender} gameState={props.gameState}
          week={week} weekInfo={weekInfo}
        />
      )}

      </div>{/* === /B: CONTENT === */}

      {/* === C: FOOTER === */}
      <div className="flex-shrink-0 bg-[#1a1612]">
        {/* 上层：🎒 + 🌙 结束今天 */}
        <div className="px-3 pt-3 pb-2 flex gap-2 border-t border-current/30">
          <button onClick={() => { audio.click(); onOpenBag(); }}
            aria-label="背包"
            className="px-4 min-h-[44px] border border-current/60 hover:bg-current/10 active:bg-current/15 transition-colors text-sm">
            🎒
          </button>
          <button onClick={onEndDay}
            className="flex-1 min-h-[44px] py-3 border border-current/60 tracking-[0.3em] text-sm hover:bg-current hover:text-black active:bg-current/30 transition-colors duration-300">
            🌙 结束今天
          </button>
        </div>

        {/* 下层：4 tabs */}
        <div className="grid grid-cols-4 border-t border-current/20
                        pb-[max(0.5rem,env(safe-area-inset-bottom))]">
          <button onClick={() => { audio.click(); setTab('map'); }}
            className={`flex flex-col items-center py-2 active:bg-current/10 transition-colors ${tab === 'map' ? 'text-[#d4b070]' : 'opacity-55'}`}>
            <span className="text-[18px] leading-none">🗺️</span>
            <span className="text-[10px] mt-0.5 tracking-wide">地图</span>
          </button>
          <button onClick={() => {
            audio.click();
            setTab('phone'); onReadMessages(); onReadGroup && onReadGroup();
          }}
            className={`flex flex-col items-center py-2 active:bg-current/10 transition-colors ${tab === 'phone' ? 'text-[#d4b070]' : 'opacity-55'}`}>
            <span className="text-[18px] leading-none">💬</span>
            <span className="text-[10px] mt-0.5 tracking-wide">
              消息{(unreadMessages + unreadGroup) > 0 &&
                <span className="ml-0.5 px-1 rounded text-white text-[8px]" style={{ background: '#f97316' }}>
                  {unreadMessages + unreadGroup}
                </span>}
            </span>
          </button>
          {flags?.link2ur_discovered ? (
            <button onClick={() => { audio.click(); setTab('link2ur'); }}
              className={`flex flex-col items-center py-2 active:bg-current/10 transition-colors ${tab === 'link2ur' ? 'text-[#d4b070]' : 'opacity-55'}`}>
              <span className="text-[18px] leading-none" style={{ color: '#007AFF' }}>L</span>
              <span className="text-[10px] mt-0.5 tracking-wide">Link2Ur</span>
            </button>
          ) : (
            <div className="flex flex-col items-center py-2 opacity-30">
              <span className="text-[18px] leading-none">🔒</span>
              <span className="text-[10px] mt-0.5 tracking-wide">锁定</span>
            </div>
          )}
          <button onClick={() => { audio.click(); setTab('journal'); }}
            className={`flex flex-col items-center py-2 active:bg-current/10 transition-colors ${tab === 'journal' ? 'text-[#d4b070]' : 'opacity-55'}`}>
            <span className="text-[18px] leading-none">📔</span>
            <span className="text-[10px] mt-0.5 tracking-wide">
              手账{diaryTotal > 0 && <span className="ml-0.5 opacity-60">·{diaryTotal}</span>}
            </span>
          </button>
        </div>
      </div>{/* === /C: FOOTER === */}
    </div>
  );
}
export function HolidayScreen({ type, choices, secrets, stats, npcRel, storyProgress, flags, feedback, onChoose, onDismiss, gender }) {
  const config = type === 'xmas'
    ? { title: '🎄 圣诞假期', subtitle: 'Christmas Vacation · 3 weeks',
        intro: '12月23日。学校关门四周。\n\n大部分英国学生回家了。Tesco 营业时间缩短。中餐馆关三天。\n\n你怎么过这个圣诞？' }
    : { title: '🐣 复活节假期', subtitle: 'Easter Vacation · 4 weeks',
        intro: '4月初。复活节假期开始。\n\n4 周时间，没人管你。期末考还有一个月。\n\n你想怎么用这段时间？' };

  // 计算解锁的隐藏剧情
  const unlockedSecrets = (secrets || []).filter(s =>
    s.condition({ npcRel: npcRel || {}, storyProgress: storyProgress || {}, flags: flags || {} })
  );

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4" style={{ background: 'rgba(10, 8, 6, 0.95)' }}>
      <div className="bg-[#1a1612] border border-amber-300/40 max-w-md w-full max-h-[90vh] overflow-y-auto p-5 animate-fadein">
        <div className="text-xs tracking-[0.3em] opacity-50 mb-1" style={{ fontFamily: 'monospace' }}>HOLIDAY</div>
        <h2 className="text-2xl mb-1 font-light">{config.title}</h2>
        <div className="text-xs opacity-60 italic mb-4" style={{ fontFamily: 'monospace' }}>{config.subtitle}</div>

        {!feedback ? (
          <>
            <div className="text-sm opacity-90 mb-5 whitespace-pre-line" style={{ lineHeight: '1.8' }}>{config.intro}</div>

            {/* 隐藏剧情区域（如果有解锁的） */}
            {unlockedSecrets.length > 0 && (
              <div className="mb-4">
                <div className="flex items-center gap-2 mb-2">
                  <div className="flex-1 h-px bg-amber-300/30" />
                  <div className="text-xs tracking-[0.3em]" style={{ fontFamily: 'monospace', color: '#d4b070' }}>
                    ⭐ SPECIAL
                  </div>
                  <div className="flex-1 h-px bg-amber-300/30" />
                </div>
                <div className="space-y-2">
                  {unlockedSecrets.map((s) => {
                    const cantAfford = (s.effect.wallet || 0) < 0 && stats.wallet + s.effect.wallet < 0;
                    const npc = s.npc ? NPCS[s.npc] : null;
                    return (
                      <button key={s.id} onClick={() => !cantAfford && onChoose(s)} disabled={cantAfford}
                        className={`w-full text-left p-3 border-2 transition-all relative ${cantAfford ? 'border-amber-300/20 opacity-30 cursor-not-allowed' : 'border-amber-300/50 hover:border-amber-300 hover:bg-amber-300/5'}`}
                        style={{ background: cantAfford ? undefined : 'linear-gradient(135deg, rgba(212,176,112,0.04), transparent)' }}>
                        <div className="flex items-start gap-2">
                          {npc && <NpcAvatar npc={npc} gender={gender} size={28} />}
                          <div className="flex-1">
                            <div className="text-sm font-medium flex items-center gap-2">
                              <span>{s.label}</span>
                              <span className="text-xs px-1.5 py-0.5 border border-amber-300/40 rounded" style={{ color: '#d4b070', fontFamily: 'monospace' }}>SECRET</span>
                            </div>
                            <div className="text-xs opacity-60 italic mt-0.5">{s.desc}{cantAfford && ' · 钱不够'}</div>
                          </div>
                        </div>
                      </button>
                    );
                  })}
                </div>
                <div className="flex items-center gap-2 mt-2 mb-3">
                  <div className="flex-1 h-px bg-current/20" />
                  <div className="text-xs opacity-50" style={{ fontFamily: 'monospace' }}>OR</div>
                  <div className="flex-1 h-px bg-current/20" />
                </div>
              </div>
            )}

            {/* 普通选项 */}
            <div className="space-y-2">
              {choices.map((c, i) => {
                const cantAfford = (c.effect.wallet || 0) < 0 && stats.wallet + c.effect.wallet < 0;
                return (
                  <button key={i} onClick={() => !cantAfford && onChoose(c)} disabled={cantAfford}
                    className={`w-full text-left p-3 border ${cantAfford ? 'border-current/10 opacity-30 cursor-not-allowed' : 'border-current/40 hover:border-current hover:bg-current/5'} transition-all`}>
                    <div className="text-sm font-medium">{c.label}</div>
                    <div className="text-xs opacity-60 italic mt-0.5">{c.desc}{cantAfford && ' · 钱不够'}</div>
                  </button>
                );
              })}
            </div>
          </>
        ) : (
          <>
            <div className="border-l-2 border-amber-300/60 pl-4 py-1 mb-4 italic opacity-90 text-sm" style={{ lineHeight: '1.8' }}>{feedback}</div>
            <button onClick={onDismiss} className="w-full px-6 py-2 border border-current text-sm tracking-[0.2em] hover:bg-current hover:text-black transition-colors">回到伦敦</button>
          </>
        )}
      </div>
    </div>
  );
}

export function ExamScreen({ exam, academic, onFinish }) {
  const [phase, setPhase] = useState('intro');
  const [currentQ, setCurrentQ] = useState(0);
  const [answers, setAnswers] = useState([]);
  const [score, setScore] = useState(0);

  function start() { audio.click(); setPhase('quiz'); }

  function answer(choiceIdx) {
    audio.click();
    const q = exam.questions[currentQ];
    const correct = choiceIdx === q.correct;
    const newAnswers = [...answers, { q: currentQ, picked: choiceIdx, correct }];
    setAnswers(newAnswers);
    if (currentQ + 1 < exam.questions.length) {
      setCurrentQ(currentQ + 1);
    } else {
      // 计算分数 (50% from quiz + 50% from academic stat)
      const quizScore = (newAnswers.filter(a => a.correct).length / exam.questions.length) * 100;
      const finalScore = Math.round(quizScore * 0.6 + academic * 0.4);
      setScore(finalScore);
      setPhase('result');
    }
  }

  function done() { audio.click(); onFinish(score); }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4" style={{ background: 'rgba(10, 8, 6, 0.95)' }}>
      <div className="bg-[#1a1612] border border-red-400/40 max-w-md w-full max-h-[90vh] overflow-y-auto p-5 animate-fadein">
        <div className="text-xs tracking-[0.3em] mb-1" style={{ fontFamily: 'monospace', color: '#c86060' }}>✍️ FINAL EXAM</div>
        <h2 className="text-xl mb-1 font-light">{exam.subject}</h2>
        <div className="text-xs opacity-60 italic mb-4" style={{ fontFamily: 'monospace' }}>{exam.cn}</div>

        {phase === 'intro' && (
          <>
            <div className="text-sm opacity-90 mb-5" style={{ lineHeight: '1.8' }}>
              考试时间：3 小时<br/>
              形式：5 道选择题<br/>
              <span className="opacity-70 italic">最终成绩 = 60% 答题正确率 + 40% 平时学业积累。所以平时不下功夫，临场也救不了你。</span>
            </div>
            <button onClick={start} className="w-full py-3 border border-current hover:bg-current hover:text-black transition-colors tracking-[0.2em] text-sm">
              开始考试
            </button>
          </>
        )}

        {phase === 'quiz' && (
          <>
            <div className="text-xs opacity-60 mb-2" style={{ fontFamily: 'monospace' }}>问题 {currentQ + 1} / {exam.questions.length}</div>
            <div className="text-sm mb-4 leading-relaxed" style={{ lineHeight: '1.7' }}>{exam.questions[currentQ].q}</div>
            <div className="space-y-2">
              {exam.questions[currentQ].options.map((opt, i) => (
                <button key={i} onClick={() => answer(i)}
                  className="w-full text-left p-3 border border-current/40 hover:border-current hover:bg-current/5 transition-all text-sm">
                  <span className="opacity-50 mr-2" style={{ fontFamily: 'monospace' }}>{String.fromCharCode(65 + i)}.</span>
                  {opt}
                </button>
              ))}
            </div>
          </>
        )}

        {phase === 'result' && (
          <>
            <div className="text-center my-6">
              <div className="text-xs opacity-60 mb-1" style={{ fontFamily: 'monospace' }}>YOUR MARK</div>
              <div className="text-6xl font-light" style={{ color: score >= 70 ? '#a0c890' : score >= 50 ? '#d4b070' : '#c86060', fontFamily: 'monospace' }}>{score}</div>
              <div className="text-sm opacity-70 italic mt-2">
                {score >= 70 ? 'Distinction · 优秀' : score >= 60 ? 'Merit · 良好' : score >= 50 ? 'Pass · 及格' : 'Fail · 挂科'}
              </div>
            </div>
            <div className="text-sm opacity-80 italic mb-5 text-center" style={{ lineHeight: '1.7' }}>
              {score >= 70 ? '走出考场你给自己买了杯 £4.5 的拿铁。今天值得。'
                : score >= 50 ? '没有大获全胜，但也没翻车。这就够了。'
                : '你坐在长椅上发了 20 分钟呆。然后你回家煮了一碗面。明天还要继续。'}
            </div>
            <button onClick={done} className="w-full px-6 py-2 border border-current text-sm tracking-[0.2em] hover:bg-current hover:text-black transition-colors">CONTINUE</button>
          </>
        )}
      </div>
    </div>
  );
}

export function DissertationTopicScreen({ feedback, onChoose, onDismiss }) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4" style={{ background: 'rgba(10, 8, 6, 0.95)' }}>
      <div className="bg-[#1a1612] border border-purple-300/40 max-w-md w-full max-h-[90vh] overflow-y-auto p-5 animate-fadein">
        <div className="text-xs tracking-[0.3em] mb-1" style={{ fontFamily: 'monospace', color: '#9080b8' }}>📝 DISSERTATION</div>
        <h2 className="text-xl mb-1 font-light">选一个论文方向</h2>
        <div className="text-xs opacity-60 italic mb-4" style={{ fontFamily: 'monospace' }}>15,000 字 · 接下来 16 周</div>

        {!feedback ? (
          <>
            <div className="text-sm opacity-90 mb-5" style={{ lineHeight: '1.8' }}>
              这是你硕士的 50%。Whitmore 让你在三个方向里选一个。<br/>
              <span className="opacity-70 italic">你的选择不只决定分数，也决定你这一年到底想成为一个什么样的人。</span>
            </div>
            <div className="space-y-2">
              {DISSERTATION_TOPICS.map((t, i) => (
                <button key={i} onClick={() => onChoose(t)}
                  className="w-full text-left p-3 border border-current/40 hover:border-current hover:bg-current/5 transition-all">
                  <div className="text-sm font-medium">{t.label}</div>
                  <div className="text-xs opacity-60 italic mt-0.5">{t.desc}</div>
                </button>
              ))}
            </div>
          </>
        ) : (
          <>
            <div className="border-l-2 border-purple-300/60 pl-4 py-1 mb-4 italic opacity-90 text-sm" style={{ lineHeight: '1.8' }}>{feedback}</div>
            <button onClick={onDismiss} className="w-full px-6 py-2 border border-current text-sm tracking-[0.2em] hover:bg-current hover:text-black transition-colors">开始动笔</button>
          </>
        )}
      </div>
    </div>
  );
}
export function BirthdayPromptScreen({ onSelect }) {
  const [gender, setGender] = useState(null);
  const months = [
    { num: 1, name: '一月' }, { num: 2, name: '二月' }, { num: 3, name: '三月' },
    { num: 4, name: '四月' }, { num: 5, name: '五月' }, { num: 6, name: '六月' },
    { num: 7, name: '七月' }, { num: 8, name: '八月' }, { num: 9, name: '九月' },
    { num: 10, name: '十月' }, { num: 11, name: '十一月' }, { num: 12, name: '十二月' },
  ];
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 animate-fadein"
      style={{ background: 'rgba(10, 8, 6, 0.95)' }}>
      <div className="bg-[#1a1612] border border-amber-300/40 max-w-md w-full p-6">
        <div className="text-xs tracking-[0.3em] opacity-50 mb-2" style={{ fontFamily: 'monospace' }}>BEFORE WE BEGIN</div>

        <h2 className="text-xl mb-2 font-light">你是男生还是女生？</h2>
        <div className="text-xs opacity-60 italic mb-3" style={{ lineHeight: '1.6' }}>
          影响 NPC 怎么称呼你（学弟/学妹、哥/姐、儿子/女儿）。
        </div>
        <div className="grid grid-cols-2 gap-2 mb-6">
          <button onClick={() => setGender('male')}
            className={`p-3 border transition-all text-sm ${gender === 'male'
              ? 'border-amber-300 bg-amber-300/10' : 'border-current/40 hover:border-amber-300/70'}`}>
            ♂ 男生
          </button>
          <button onClick={() => setGender('female')}
            className={`p-3 border transition-all text-sm ${gender === 'female'
              ? 'border-amber-300 bg-amber-300/10' : 'border-current/40 hover:border-amber-300/70'}`}>
            ♀ 女生
          </button>
        </div>

        <h2 className="text-xl mb-2 font-light">你的生日是哪个月？</h2>
        <div className="text-sm opacity-80 italic mb-4" style={{ lineHeight: '1.7' }}>
          这一年里你会经历它一次。<br/>
          <span className="opacity-60">在异乡过的第一个生日，是会被记住的。</span>
        </div>
        <div className={`grid grid-cols-3 gap-2 ${!gender ? 'opacity-40 pointer-events-none' : ''}`}>
          {months.map(m => (
            <button key={m.num} onClick={() => gender && onSelect(m.num, gender)}
              className="p-2.5 border border-current/40 hover:border-amber-300 hover:bg-amber-300/5 transition-all text-sm">
              {m.name}
            </button>
          ))}
        </div>
        {!gender && (
          <div className="text-xs opacity-50 italic text-center mt-3">先选个性别 ↑</div>
        )}
      </div>
    </div>
  );
}
export function TravelScreen({ destination, daysLeft, totalDays, events, allEvents, seenEvents,
  stats, onChooseEvent, onSkipDay, onFinish }) {

  const cityBg = {
    edinburgh: 'linear-gradient(180deg, #4a5568 0%, #2d3748 100%)',
    paris: 'linear-gradient(180deg, #d4a574 0%, #8b6f47 50%, #2d2520 100%)',
    amsterdam: 'linear-gradient(180deg, #5a8a70 0%, #2a4a3a 100%)',
    rome: 'linear-gradient(180deg, #d49060 0%, #7a4828 100%)',
  }[destination.id] || 'linear-gradient(180deg, #2a2520 0%, #1a1612 100%)';

  const dayUsed = totalDays - daysLeft + 1;

  return (
    <div className="fixed inset-0 z-40 flex items-center justify-center p-4 animate-fadein"
      style={{ background: cityBg }}>
      <div className="bg-[#1a1612]/95 border border-amber-300/40 max-w-md w-full max-h-[90vh] overflow-y-auto p-5 backdrop-blur">
        <div className="text-xs tracking-[0.4em] mb-1" style={{ fontFamily: 'monospace', color: '#d4b070' }}>
          ✈️ TRAVEL
        </div>
        <div className="flex justify-between items-baseline mb-3">
          <div>
            <h2 className="text-2xl font-light">{destination.name}</h2>
            <div className="text-xs opacity-60 italic" style={{ fontFamily: 'monospace' }}>{destination.desc}</div>
          </div>
          <div className="text-right">
            <div className="text-xs opacity-60" style={{ fontFamily: 'monospace' }}>DAY {dayUsed}/{totalDays}</div>
            <div className="flex gap-1 mt-1 justify-end">
              {[...Array(totalDays)].map((_, i) => (
                <div key={i} className={`w-2 h-2 rounded-full border ${i < totalDays - daysLeft + 1 ? 'bg-amber-300/80 border-amber-300' : 'border-current/30'}`} />
              ))}
            </div>
          </div>
        </div>

        {/* 已收集的明信片 */}
        {seenEvents.length > 0 && (
          <div className="mb-4 px-3 py-2 border border-amber-300/30 bg-amber-300/5">
            <div className="text-xs tracking-[0.2em] opacity-60 mb-1.5" style={{ fontFamily: 'monospace' }}>
              ✉️ POSTCARDS · {seenEvents.length}/{allEvents.length}
            </div>
            <div className="text-xs opacity-80 italic space-y-0.5">
              {allEvents.filter(e => seenEvents.includes(e.id) && e.postcard).map(e => (
                <div key={e.id}>· {e.postcard}</div>
              ))}
            </div>
          </div>
        )}

        <div className="text-xs tracking-[0.2em] opacity-60 mb-2" style={{ fontFamily: 'monospace' }}>今天做什么？</div>

        {events.length > 0 ? (
          <div className="space-y-2 mb-3">
            {events.map(ev => (
              <button key={ev.id} onClick={() => onChooseEvent(ev)}
                className="w-full text-left p-3 border border-current/40 hover:border-amber-300 hover:bg-amber-300/5 transition-all">
                <div className="text-sm">{ev.title}</div>
                <div className="text-xs opacity-60 italic mt-0.5 line-clamp-2">{ev.body.split('\n')[0]}</div>
              </button>
            ))}
          </div>
        ) : (
          <div className="text-sm opacity-70 italic mb-4">你已经看过了{destination.name}所有的角落。该回家了。</div>
        )}

        <div className="flex gap-2 mt-4">
          <button onClick={onSkipDay}
            className="flex-1 py-2 border border-current/40 text-sm hover:border-current transition-all">
            跳过今天 →
          </button>
          {(daysLeft <= 1 || events.length === 0) && (
            <button onClick={onFinish}
              className="flex-1 py-2 border border-amber-300/60 text-sm hover:bg-amber-300/10 transition-all"
              style={{ color: '#d4b070' }}>
              回伦敦 ✈️
            </button>
          )}
        </div>
      </div>
    </div>
  );
}
export function EndingScreen({ ending, stats, npcRel, attendanceRate, storyProgress, examResults, dissertationProgress, postcards, flags, addedStrangers, gender, onRestart }) {
  // Lazy pronounize so we don't pull engine into Screens.jsx — App.jsx will
  // pass already-processed echoes via gender, but for echoes built inline we
  // do a tiny replace here.
  const pn = (s) => {
    if (!s || !gender) return s;
    return s.replace(/林可儿\s*\/\s*林楠/g, gender === 'female' ? '林楠' : '林可儿')
            .replace(/他\s*\/\s*她/g, gender === 'female' ? '她' : '他')
            .replace(/她\s*\/\s*他/g, gender === 'female' ? '他' : '她')
            .replace(/学弟\s*\/\s*学妹/g, gender === 'female' ? '学妹' : '学弟')
            .replace(/男生\s*\/\s*女生/g, gender === 'female' ? '女生' : '男生')
            .replace(/儿子\s*\/\s*女儿/g, gender === 'female' ? '女儿' : '儿子')
            .replace(/侄子\s*\/\s*侄女/g, gender === 'female' ? '侄女' : '侄子');
  };

  // 根据 flag 生成回响段落
  const echoes = [];

  // 父母线 - 最重的回响放在最前
  if (flags?.parents_visited) {
    echoes.push({
      who: '爸妈', avatar: '家', color: '#d4b070',
      text: '你回国后第一次见到爸妈。妈妈一开门就说"瘦了瘦了 吃饭吃饭"。\n\n爸爸坐下来看你。看了 30 秒。然后说："这一年 你长大了。"\n\n你说："我看到你那次擦眼泪了。"\n\n他愣了一下。然后说："瞎说。" 然后他自己笑了。\n\n你妈端菜出来："还在那擦什么 吃饭。"\n\n你看着这一桌子菜。看着他们。\n\n你想：原来我留学这一年 是为了能看清楚我爸妈的样子。'
    });
  } else if (flags?.parents_declined) {
    echoes.push({
      who: '爸妈', avatar: '家', color: '#a89070',
      text: '毕业后你回国。第一晚和爸妈吃饭。\n\n你妈一直夹菜给你。爸爸在旁边喝汤。\n\n你突然说："那一年... 你们要是真的来 该多好。"\n\n你妈停下手："那时候你不让我们来。"\n\n你说"我知道。是我蠢。"\n\n你爸放下汤勺："下次。等你工作了 我们去看你。"\n\n下次没有真的来。但他说的"下次"你记着了。'
    });
  }

  if (flags?.kaize_friend) {
    echoes.push({
      who: '凯泽', avatar: '凯', color: '#7a8a6a',
      text: flags.kaize_friend
        ? '毕业半年后，你收到一张从新加坡寄来的手写卡片。\n\n"哥们/姐们 你不知道你那次帮我有多重要。我现在在新加坡上班了。这张卡片随便放。重要的是你看到这一行字：你救过我。"'
        : ''
    });
  }
  if (flags?.helped_xl) {
    echoes.push({
      who: '小李', avatar: '李', color: '#a87fb8',
      text: '一年后你刷到小红书。她已经 80 万粉丝。最新一条 vlog 末尾她说："这个频道开始的那个下午，有一个人陪我拍。我们没拍到 ta 的脸 但我永远记得那一天。" 评论区第一条："谁啊 求 cp"。\n\n你笑了，没回复。'
    });
  }
  if (flags?.aq_advised) {
    echoes.push({
      who: '阿强', avatar: '强', color: '#7a8a6a',
      text: '阿强真的结婚了。他给你寄了请柬——三亚。机票他报销。\n\n你犹豫了一周。最后你订了机票。\n\n婚礼那天他抱着你说："我一辈子记着你那次跟我说的话。"'
    });
  }
  if (flags?.tt_offer_dinner) {
    echoes.push({
      who: '婷婷', avatar: '婷', color: '#d4a4c0',
      text: '婷婷在 Goldman Sachs 入职前给你发了一条消息：\n\n"我下个月去香港 office 报到。如果你以后想跳金融 找我。我在 G 司给你内推。这不是客气。"\n\n你想：原来在伦敦认识一个人 三年后她可能就变成了你人生的一扇门。'
    });
  }
  if (flags?.helped_zhou) {
    echoes.push({
      who: '老周', avatar: '周', color: '#9a7050',
      text: '老周也毕业了。回国前他给你的快递箱里塞了一袋家乡茶叶 + 一封手写信。\n\n信里："小同学 你不知道你帮我改的那篇 essay 在我家是个传奇。我儿子现在跟同学说\'我爸 40 岁还能拿 distinction\'。这是你的功劳。"\n\n你把那袋茶喝了 1 年。'
    });
  }
  if (flags?.dj_marathon_cheer) {
    echoes.push({
      who: '大江', avatar: '江', color: '#c4615a',
      text: '大江把那块"加油"的牌子带回了国。后来他朋友圈发他儿子拿着那块牌子的照片。配文："这是爸爸 22 岁那年 一个朋友给我做的。爸爸希望你以后也有这样的朋友。"'
    });
  }
  if (flags?.lulu_painting) {
    echoes.push({
      who: '露露', avatar: '露', color: '#d4b070',
      text: '露露后来真的成了画家。她的第一次个展在伦敦 Soho。开幕邀请函只有 50 张。其中一张寄到了你北京的家。\n\n邀请函背面她手写："你是我画过最孤独的那幅画的第一个观众。"'
    });
  }
  if (flags?.phd_offer_open) {
    echoes.push({
      who: '上岸了的姐', avatar: '岸', color: '#9080b8',
      text: '你最后没去申请那个 PhD。但毕业 3 年后，上岸了的姐发来一条消息：\n\n"我们组又有 1 个 funded 名额。你现在准备好了吗？"\n\n你看了 1 小时这条消息。然后回："我准备一下。"'
    });
  }
  // 借钱 / 留宿等用 npc kaize_friend 来追踪 - 已在上面
  // 新生小王告别
  if (flags?.xiao_wang_goodbye) {
    echoes.push({
      who: '新生小王', avatar: '王', color: '#d4b070',
      text: '新生小王回国后没怎么联系。但有一天他突然给你寄了一封信——纸是他自己折的。\n\n"哥/姐 我现在国内一家小公司上班。挺好的。我有时候还会想伦敦。但 我没后悔。\n\n谢谢你那次去 Pret 见我。我就是想跟一个人吃顿饭再走。是你来了。"'
    });
  }

  // ── 批次 6 / 7 新增 echo ──
  if (flags?.mark_kept_in_touch) {
    echoes.push({
      who: 'Mark', avatar: 'M', color: '#a07060',
      text: '毕业 2 年后你回伦敦出差。\n\n你按 Mark 卡片上写的地址去了 Tottenham 那家 boozer。一进门——他在吧台后擦杯子。他妈接手了 pub，他帮忙。\n\n他看到你愣了 3 秒："Fuck me, you actually came." 然后他抱了你。\n\n他给你做了一份 Sunday roast 没收钱。"On me. As promised."\n\n那块焦黑的炒锅他还留着——挂在 pub 厨房的墙上。'
    });
  }
  if (flags?.aisha_friend && flags?.eid_lunch) {
    echoes.push({
      who: 'Aisha', avatar: 'A', color: '#7080a0',
      text: '毕业 1 年后她寄给你一张明信片——从 Lahore 寄出，盖了 5 个国际邮戳。\n\n上面她妈妈用乌尔都语写了一句，下面 Aisha 翻译："My mother says: \'You are family. Come back when you are ready. The biryani will be hot.\'"'
    });
  }
  if (flags?.marcus_solidarity) {
    echoes.push({
      who: 'Marcus', avatar: 'M', color: '#5a4a3a',
      text: 'Marcus 拿了 PhD。一年后他在 LinkedIn 上发了个新职位——Lecturer at 某个 university。\n\n他 caption 写："To everyone who told me \'where are you really from\'—I\'m from Hackney. And now I\'m the one teaching tutorials. Get in."\n\n你点了赞 + 评论 "Mate."。他回 "Mate."。这是 5 年的 friendship 浓缩成 2 个 mate。'
    });
  }
  if (flags?.park_supported) {
    echoes.push({
      who: 'Park', avatar: '朴', color: '#9080a0',
      text: 'Park 没回韩国。3 年后 ta 在 Wigmore Hall 开了 ta 第一场独奏会——你在 LinkedIn 上看到。\n\n演出节目单最后写了一段："This concert is dedicated to the friend who told me, at 2am in November of my master\'s year, \'You\'re an adult.\' That sentence kept me here."\n\n你不知道是不是说你。你也知道是说你。'
    });
  }
  if (flags?.linnan_stay_together) {
    echoes.push({
      who: '林可儿 / 林楠', avatar: '林', color: '#a07090',
      text: '5 年后你和林可儿 / 林楠都拿到了 ILR。你们买了 Hackney 一套二居（30 万首付）。\n\n搬家那天 ta 翻出一个旧盒子——里面是 ta 当年那本 Foucault 笔记。你写的字。\n\nta 说："你那时候字真丑。" 你说"我现在也丑"。'
    });
  }
  if (flags?.sent_first_money_home) {
    echoes.push({
      who: '妈', avatar: '家', color: '#d4b070',
      text: '回国第一年春节。你妈把那 ¥2,000 的 transfer 截图打印出来塞进相册。\n\n姑姑来拜年看到："这是什么？" 你妈："我儿子 / 女儿在伦敦自己赚了第一笔钱给我的。我留着。"\n\n姑姑说"哎呀这种事不就转账嘛"。你妈说："你不懂。"'
    });
  }
  if (flags?.mei_manager_path) {
    echoes.push({
      who: 'Mei 姐', avatar: '梅', color: '#b85070',
      text: '毕业 3 年后 Mei 姐邀请你回伦敦——她给你寄了机票。\n\n你下飞机 Lucky Star 已经开了 4 家分店。她在 Camden 新店剪彩那天叫你站在她旁边。\n\n媒体问"是您徒弟吗？" Mei 姐："不是徒弟。是侄子 / 侄女。"\n\n你在台上没说话——但你手在颤。'
    });
  }
  if (flags?.aditi_supported) {
    echoes.push({
      who: 'Aditi', avatar: 'A', color: '#a87fb8',
      text: '她爸去世后第二年。你在 Bangalore 收到一个邮包——铜质小盒子里那枚护身符。\n\n附信："My mum said this was meant to be passed down. She wants you to have it. \'You came when our family needed someone outside the family.\'"\n\n你戴上。它和你这一年其它东西不一样——它是别人家的母亲选你戴的。'
    });
  }
  if (flags?.whitmore_last_meeting) {
    echoes.push({
      who: 'Whitmore', avatar: 'W', color: '#7a8a6a',
      text: '退休后他真去了 Yorkshire 那栋 cottage。每年圣诞他寄一张手写卡——黑墨水钢笔，他妻子的字迹模仿他的。\n\n第三年他寄来的卡说："I read what you wrote in *Cambridge Review*. She would have been proud. James."\n\n他不知道你哭了 1 小时。'
    });
  }

  return (
    <div className="animate-fadein-slow max-w-2xl mx-auto pt-12 pb-8">
      <div className="text-xs tracking-[0.4em] opacity-50 mb-3" style={{ fontFamily: 'monospace' }}>ENDING · {ending.subtitle.toUpperCase()}</div>
      <h2 className="text-5xl mb-2 font-light">{ending.title}</h2>
      <div className="text-sm opacity-60 italic mb-10">{ending.subtitle}</div>
      <div className="text-base leading-relaxed mb-10 opacity-90 whitespace-pre-line" style={{ lineHeight: '2' }}>{ending.text}</div>

      {echoes.length > 0 && (
        <div className="border-t border-current/20 pt-6 mb-6">
          <div className="text-xs tracking-[0.3em] opacity-50 mb-4" style={{ fontFamily: 'monospace' }}>📮 那些没忘记的人</div>
          <div className="space-y-5">
            {echoes.map((e, i) => (
              <div key={i} className="flex gap-3 items-start">
                <div className="w-8 h-8 rounded-full flex items-center justify-center text-xs font-medium flex-shrink-0"
                  style={{ background: e.color, color: '#1a1612' }}>{e.avatar}</div>
                <div className="flex-1">
                  <div className="text-xs opacity-60 mb-1.5" style={{ fontFamily: 'monospace' }}>· {pn(e.who)} ·</div>
                  <div className="text-sm italic opacity-90 whitespace-pre-line" style={{ lineHeight: '1.95' }}>
                    {pn(e.text)}
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      <div className="border-t border-current/20 pt-6 mb-6 space-y-4">
        <div>
          <div className="text-xs tracking-[0.3em] opacity-50 mb-2" style={{ fontFamily: 'monospace' }}>FINAL STATS</div>
          <div className="grid grid-cols-5 gap-2 text-xs">
            <div><div className="opacity-60">学业</div><div style={{ fontFamily: 'monospace' }}>{stats.academic}%</div></div>
            <div><div className="opacity-60">钱包</div><div style={{ fontFamily: 'monospace' }}>£{stats.wallet}</div></div>
            <div><div className="opacity-60">精力</div><div style={{ fontFamily: 'monospace' }}>{stats.energy}%</div></div>
            <div><div className="opacity-60">归属</div><div style={{ fontFamily: 'monospace' }}>{stats.belonging}%</div></div>
            <div><div className="opacity-60">出勤</div><div style={{ fontFamily: 'monospace' }}>{attendanceRate}%</div></div>
          </div>
        </div>

        {examResults && Object.keys(examResults).length > 0 && (
          <div>
            <div className="text-xs tracking-[0.3em] opacity-50 mb-2" style={{ fontFamily: 'monospace' }}>EXAMS</div>
            <div className="grid grid-cols-3 gap-2 text-xs">
              {Object.entries(examResults).map(([id, score]) => {
                const exam = EXAM_PAPERS.find(e => e.id === id);
                return (
                  <div key={id}>
                    <div className="opacity-60">{exam?.cn || id}</div>
                    <div style={{ fontFamily: 'monospace', color: score >= 70 ? '#a0c890' : score >= 50 ? '#d4b070' : '#c86060' }}>{score}%</div>
                  </div>
                );
              })}
            </div>
          </div>
        )}

        {dissertationProgress > 0 && (
          <div>
            <div className="text-xs tracking-[0.3em] opacity-50 mb-2" style={{ fontFamily: 'monospace' }}>DISSERTATION</div>
            <div className="text-xs" style={{ fontFamily: 'monospace' }}>完成度 {dissertationProgress}%</div>
          </div>
        )}

        <div>
          <div className="text-xs tracking-[0.3em] opacity-50 mb-2" style={{ fontFamily: 'monospace' }}>STORIES UNLOCKED</div>
          <div className="space-y-1 text-xs">
            {Object.values(STORYLINES).map(line => (
              <div key={line.id} className="flex justify-between">
                <span>{line.name}</span>
                <span style={{ fontFamily: 'monospace' }}>{storyProgress[line.id] || 0} / {line.chapters.length}</span>
              </div>
            ))}
          </div>
        </div>

        {postcards && postcards.length > 0 && (
          <div>
            <div className="text-xs tracking-[0.3em] opacity-50 mb-2" style={{ fontFamily: 'monospace' }}>✉️ POSTCARDS · {postcards.length}</div>
            <div className="space-y-1 text-xs italic opacity-80">
              {postcards.map(p => (
                <div key={p.id}>{p.text}</div>
              ))}
            </div>
          </div>
        )}
      </div>

      <button onClick={onRestart} className="px-12 py-3 border border-current tracking-[0.3em] text-sm hover:bg-current hover:text-black transition-colors duration-500">AGAIN</button>
      <div className="mt-12 text-xs opacity-30 italic text-center">每一次重来都是不同的人生。</div>

      {/* ── 片尾 CTA / Post-credits ── 与主结局留 200px 大间隔 ── */}
      <div className="mt-48 pt-12 border-t border-current/15">
        <Link2UrPostCredits />
      </div>
    </div>
  );
}

// ──────────────────────────────────────────────────────
// Post-credits CTA — 致谢 credit roll 之后单独一屏，
// 不打断结局情绪（与 AGAIN 按钮中间留 mt-48 隔断）。
// ──────────────────────────────────────────────────────
function Link2UrPostCredits() {
  return (
    <div className="text-center pt-8 pb-16 animate-fadein-slow">
      <div className="text-xs tracking-[0.4em] opacity-50 mb-12" style={{ fontFamily: 'monospace' }}>
        — 片尾 · END CREDITS —
      </div>

      <div className="max-w-md mx-auto mb-10 text-sm leading-relaxed opacity-80 italic" style={{ lineHeight: '2' }}>
        <p className="mb-2">这一年是虚构的。</p>
        <p>但 Link2Ur 是真的——也许有人正等着你帮一把。</p>
      </div>

      <div className="mb-2 flex items-center justify-center gap-3">
        <div className="w-10 h-10 rounded flex items-center justify-center text-xl font-bold"
          style={{ background: '#007AFF', color: 'white' }}>L</div>
        <div className="text-3xl font-light tracking-wide" style={{ color: '#007AFF' }}>Link2Ur</div>
      </div>
      <div className="text-sm opacity-70 italic mb-8">留学生互助平台</div>

      <div className="grid grid-cols-3 gap-4 max-w-md mx-auto mb-6">
        <QrPlaceholder label="App Store" sub="iOS" />
        <QrPlaceholder label="Google Play" sub="Android" />
        <QrPlaceholder label="link2ur.com" sub="Web" />
      </div>

      <div className="text-xs opacity-50 italic mb-2">扫码下载 · 全球留学生在用</div>
      <div className="text-xs opacity-30" style={{ fontFamily: 'monospace' }}>Made with ♥ in London · 2026</div>
    </div>
  );
}

function QrPlaceholder({ label, sub }) {
  // 8×8 grid of cells styled to look like a QR code. Replace with <img src> when
  // real QR PNGs are generated for App Store / Play / web URLs.
  const cells = [];
  // Deterministic-looking pattern (uses label as seed)
  let seed = 0;
  for (const c of label) seed += c.charCodeAt(0);
  for (let i = 0; i < 64; i++) {
    seed = (seed * 1103515245 + 12345) & 0x7fffffff;
    cells.push((seed >> 8) & 1);
  }
  // Force 3 corner finder squares
  const cornerCells = new Set([
    0, 1, 2, 8, 9, 10, 16, 17, 18,        // top-left
    5, 6, 7, 13, 14, 15, 21, 22, 23,      // top-right
    40, 41, 42, 48, 49, 50, 56, 57, 58,   // bottom-left
  ]);

  return (
    <div className="flex flex-col items-center">
      <div className="bg-white p-1.5 mb-1.5">
        <div className="grid grid-cols-8 gap-0" style={{ width: 72, height: 72 }}>
          {cells.map((on, i) => (
            <div key={i} className="w-[9px] h-[9px]"
              style={{ background: cornerCells.has(i) || on ? '#0a0a0a' : 'transparent' }} />
          ))}
        </div>
      </div>
      <div className="text-xs opacity-80" style={{ fontFamily: 'monospace' }}>{label}</div>
      <div className="text-[10px] opacity-40">{sub}</div>
    </div>
  );
}
