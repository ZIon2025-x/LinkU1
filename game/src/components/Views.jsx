import React, { useState } from 'react';
import {
  NPCS, STORYLINES, LOCATIONS, TRAVEL_DESTINATIONS, EXAM_PAPERS,
  GROUP_MEMBERS, STRANGERS, DREAMS, INSOMNIA_THOUGHTS, NOSTALGIA_MOMENTS,
} from '../data/index.js';
import { collectEntries, toMarkdown, toPNG, download } from '../engine/diaryExport.js';
import { AchievementsView } from './AchievementsView.jsx';
import { NpcAvatar } from './NpcAvatar.jsx';
import { getLocationImage, getMiscImage } from '../engine/imageRegistry.js';

export function MapView({ locations, actionsLeft, onGoToLocation, currentLocation, setCurrentLocation,
  onAttendClass, onWorkShift, onRestAtFlat, onCallHome, onTalkNPC, npcRel, day, stats, onStartTravel,
  onWriteDissertation, weekInfo, dissertationTopic,
  onTriggerPret, onTriggerEssay, onTriggerMatch, gender }) {

  if (currentLocation) {
    return <LocationView location={currentLocation} onLeave={() => setCurrentLocation(null)}
      onAttendClass={onAttendClass} onWorkShift={onWorkShift} onRestAtFlat={onRestAtFlat}
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

  return (
    <div className="animate-fadein">
      <div className="text-xs opacity-60 mb-3 italic">今天去哪？（每个地点消耗 1 行动 + 5 精力）</div>
      <div className="grid grid-cols-2 md:grid-cols-3 gap-2">
        {locations.map(loc => (
          <button key={loc.id} onClick={() => onGoToLocation(loc)} disabled={actionsLeft <= 0}
            className="p-3 border border-current/40 hover:border-current hover:bg-current/5 transition-all text-left disabled:opacity-30 disabled:cursor-not-allowed">
            <div className="text-2xl mb-1">{loc.emoji}</div>
            <div className="text-sm font-medium">{loc.name}</div>
            <div className="text-xs opacity-50 italic mt-0.5">{loc.en}</div>
          </button>
        ))}
      </div>
    </div>
  );
}

export function LocationView({ location, onLeave, onAttendClass, onWorkShift, onRestAtFlat,
  onCallHome, onTalkNPC, npcRel, day, stats, onStartTravel, actionsLeft,
  onWriteDissertation, weekInfo, dissertationTopic,
  onTriggerPret, onTriggerEssay, onTriggerMatch, gender }) {

  const npcsHere = Object.values(NPCS).filter(n => n.locations.includes(location.id));

  // 本地点的可用行动
  const actions = [];
  if (location.id === 'flat') {
    actions.push({ label: '🛌 休息', desc: '+25精力 -1归属', onClick: onRestAtFlat });
    actions.push({ label: '📞 给家里打电话', desc: '+10归属 -3精力', onClick: onCallHome });
    if (weekInfo?.type === 'dissertation' && dissertationTopic) {
      actions.push({ label: '📝 写论文（在家）', desc: `+论文进度 -12精力`, onClick: onWriteDissertation });
      actions.push({ label: '✍️ 写一段（迷你游戏）', desc: '挑战自己 +大量论文进度', onClick: onTriggerEssay });
    }
  } else if (location.id === 'uni') {
    if (weekInfo?.requireClass) {
      actions.push({ label: '📚 上课', desc: '+6学业 -8精力 +1出勤', onClick: onAttendClass });
    } else if (weekInfo?.type === 'reading') {
      actions.push({ label: '📖 自习（无课）', desc: '+4学业 -6精力', onClick: onAttendClass });
      actions.push({ label: '🎴 复习理论卡牌', desc: '迷你游戏 +学业', onClick: onTriggerMatch });
    } else if (weekInfo?.type === 'revision') {
      actions.push({ label: '☕ 复习（备考）', desc: '+5学业 -8精力', onClick: onAttendClass });
      actions.push({ label: '🎴 复习理论卡牌', desc: '迷你游戏 +学业', onClick: onTriggerMatch });
    } else if (weekInfo?.type === 'dissertation' && dissertationTopic) {
      actions.push({ label: '📝 论文 supervision meeting', desc: `+论文进度 -10精力`, onClick: onWriteDissertation });
    }
  } else if (location.id === 'library') {
    if (weekInfo?.type === 'dissertation' && dissertationTopic) {
      actions.push({ label: '📝 写论文（图书馆）', desc: `+论文进度(更高) -10精力`, onClick: onWriteDissertation });
      actions.push({ label: '✍️ 写一段（迷你游戏）', desc: '挑战自己 +大量论文进度', onClick: onTriggerEssay });
    }
    if (['reading', 'revision'].includes(weekInfo?.type)) {
      actions.push({ label: '🎴 复习理论卡牌', desc: '迷你游戏 +学业', onClick: onTriggerMatch });
    }
  } else if (location.id === 'mei') {
    if (day > 14) actions.push({ label: '💼 打工一晚', desc: '+£50 -12精力', onClick: onWorkShift });
  } else if (location.id === 'pub') {
    actions.push({ label: '💼 打工一晚', desc: '+£50 -12精力', onClick: onWorkShift });
  } else if (location.id === 'soho' || location.id === 'tate') {
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

export function PhoneView({ messages, npcRel }) {
  if (messages.length === 0) {
    return <div className="text-center opacity-50 italic py-12 text-sm">还没有消息</div>;
  }
  return (
    <div className="animate-fadein space-y-2">
      <div className="text-xs tracking-[0.2em] opacity-60 mb-2" style={{ fontFamily: 'monospace' }}>消息</div>
      {messages.slice().reverse().map(m => (
        <div key={m.id} className="p-3 border border-current/30 animate-slidein">
          <div className="flex justify-between text-xs opacity-60 mb-1">
            <span style={{ fontFamily: 'monospace' }}>{m.fromName}</span>
            <span style={{ fontFamily: 'monospace' }}>D{m.day} · {m.time}</span>
          </div>
          <div className="text-sm">{m.text}</div>
        </div>
      ))}
    </div>
  );
}

export function StoryView({ storyProgress, npcRel, monthAttendance, examResults, parentsChapter, flags, gender }) {
  const showParentsLine = parentsChapter > 0 || flags?.parents_coming || flags?.parents_declined;
  return (
    <div className="animate-fadein space-y-3">
      {/* 父母线进度 */}
      {showParentsLine && (
        <div className="p-3 border border-amber-300/40 bg-amber-300/5">
          <div className="text-xs tracking-[0.2em] mb-2 flex justify-between" style={{ fontFamily: 'monospace', color: '#d4b070' }}>
            <span>🇨🇳 父母线</span>
            <span className="opacity-60">{parentsChapter} / 5</span>
          </div>
          {flags?.parents_declined ? (
            <div className="text-xs opacity-70 italic">你拒绝了他们这次来。后面再没机会。</div>
          ) : (
            <>
              <div className="flex gap-1 mb-2">
                {[1,2,3,4,5].map(i => (
                  <div key={i} className={`flex-1 h-0.5 ${i <= parentsChapter ? 'bg-amber-300/70' : 'bg-current/20'}`} />
                ))}
              </div>
              <div className="text-xs opacity-70 italic">
                {parentsChapter === 0 ? '妈妈还没问起来过。' :
                 parentsChapter === 1 ? '妈妈问了。等春节。' :
                 parentsChapter === 2 ? '妈妈在练 "How are you"。' :
                 parentsChapter === 3 ? '他们在伦敦。' :
                 parentsChapter === 4 ? '他们在你的伦敦。' :
                 '他们走了。'}
              </div>
            </>
          )}
        </div>
      )}
      {/* 学年进度 */}
      {(monthAttendance?.length > 0 || Object.keys(examResults || {}).length > 0) && (
        <div className="p-3 border border-current/30">
          <div className="text-xs tracking-[0.2em] opacity-60 mb-2" style={{ fontFamily: 'monospace' }}>学年进度</div>
          {monthAttendance?.length > 0 && (
            <div className="mb-3">
              <div className="text-xs opacity-70 mb-1.5">月度出勤</div>
              <div className="flex gap-1">
                {monthAttendance.map((m, i) => {
                  const c = m.rate >= 80 ? '#a0c890' : m.rate >= 70 ? '#d4b070' : m.rate >= 60 ? '#d49060' : '#c86060';
                  return (
                    <div key={i} className="flex-1 text-center">
                      <div className="text-xs" style={{ color: c, fontFamily: 'monospace' }}>{m.rate}%</div>
                      <div className="h-1 mt-1" style={{ background: c }} />
                      <div className="text-xs opacity-50 mt-0.5" style={{ fontFamily: 'monospace' }}>M{m.month}</div>
                    </div>
                  );
                })}
              </div>
            </div>
          )}
          {Object.keys(examResults || {}).length > 0 && (
            <div>
              <div className="text-xs opacity-70 mb-1.5">考试成绩</div>
              <div className="space-y-1 text-xs">
                {Object.entries(examResults).map(([id, score]) => {
                  const exam = EXAM_PAPERS.find(e => e.id === id);
                  const c = score >= 70 ? '#a0c890' : score >= 50 ? '#d4b070' : '#c86060';
                  return (
                    <div key={id} className="flex justify-between" style={{ fontFamily: 'monospace' }}>
                      <span>{exam?.cn || id}</span>
                      <span style={{ color: c }}>{score}%</span>
                    </div>
                  );
                })}
              </div>
            </div>
          )}
        </div>
      )}

      <div className="text-xs tracking-[0.2em] opacity-60 mb-2" style={{ fontFamily: 'monospace' }}>故事进度</div>
      {(() => {
        // Only show storylines the player has actually started.
        const activeLines = Object.values(STORYLINES).filter(line => (storyProgress[line.id] || 0) > 0);

        if (activeLines.length === 0) {
          return (
            <div className="p-4 border border-current/20 text-xs opacity-60 italic text-center" style={{ lineHeight: '1.9' }}>
              你还没遇到谁。<br/>
              多去几个地方、和人说话，故事会自己来找你。
            </div>
          );
        }

        return activeLines.map(line => {
          const npc = NPCS[line.npc];
          const progress = storyProgress[line.id] || 0;
          const total = line.chapters.length;
          const completed = progress >= total;
          const lastChapter = line.chapters[Math.min(progress, total) - 1];
          return (
            <div key={line.id} className="p-3 border border-current/30">
              <div className="flex items-center gap-3 mb-2">
                <NpcAvatar npc={npc} gender={gender} size={32} />
                <div className="flex-1">
                  <div className="text-sm">{line.name}</div>
                  <div className="text-xs opacity-60" style={{ fontFamily: 'monospace' }}>
                    {progress}/{total} 章{completed && ' · 完结'}
                  </div>
                </div>
              </div>
              <div className="flex gap-1">
                {line.chapters.map((c, i) => (
                  <div key={i} className={`flex-1 h-1 ${i < progress ? 'bg-current' : 'bg-current/20'}`} />
                ))}
              </div>
              {lastChapter && (
                <div className="mt-2 text-xs opacity-60 italic">
                  最近：{lastChapter.title}
                </div>
              )}
            </div>
          );
        });
      })()}
    </div>
  );
}

export function DiaryView({ seenDreams, seenInsomnia, seenNostalgia, diaryChoices, unlockedAchievements, gender, gameState }) {
  const [section, setSection] = useState('all');
  const dreamEntries = (seenDreams || []).map(id => DREAMS.find(d => d.id === id)).filter(Boolean).map(d => ({...d, type: 'dream'}));
  const insomniaEntries = (seenInsomnia || []).map(id => INSOMNIA_THOUGHTS.find(i => i.id === id)).filter(Boolean).map(d => ({...d, type: 'insomnia'}));
  const nostalgiaEntries = (seenNostalgia || []).map(id => NOSTALGIA_MOMENTS.find(n => n.id === id)).filter(Boolean).map(d => ({...d, type: 'nostalgia'}));
  const choiceEntries = (diaryChoices || []).map((c, i) => ({
    id: `choice-${c.day}-${i}`, title: c.title, body: c.line, day: c.day, week: c.week, type: 'choice',
  }));

  let entries = [];
  if (section === 'all') entries = [...choiceEntries, ...dreamEntries, ...insomniaEntries, ...nostalgiaEntries];
  else if (section === 'choice') entries = choiceEntries;
  else if (section === 'dream') entries = dreamEntries;
  else if (section === 'insomnia') entries = insomniaEntries;
  else if (section === 'nostalgia') entries = nostalgiaEntries;

  const total = dreamEntries.length + insomniaEntries.length + nostalgiaEntries.length + choiceEntries.length;
  const achievementCount = unlockedAchievements?.length || 0;

  if (total === 0 && achievementCount === 0) {
    return (
      <div className="animate-fadein text-center py-12">
        <div className="text-sm opacity-50 italic mb-3">日记还是空的。</div>
        <div className="text-xs opacity-40 italic" style={{ lineHeight: '1.8' }}>
          这本子会自己写满。<br/>
          等你梦到、等你失眠、等你想家、等你做出一个值得记的决定。
        </div>
      </div>
    );
  }

  const typeStyle = {
    dream: { color: '#c8b8e0', icon: '☾', label: '梦' },
    insomnia: { color: '#a8a09c', icon: '☾', label: '失眠' },
    nostalgia: { color: '#e8c8c0', icon: '🏮', label: '想家' },
    choice: { color: '#d4b070', icon: '◆', label: '决定' },
  };

  function exportMd() {
    const buckets = collectEntries({
      diaryChoices,
      dreams: dreamEntries,
      insomnias: insomniaEntries,
      nostalgias: nostalgiaEntries,
    });
    const md = toMarkdown(buckets, { week: undefined });
    download(new Blob([md], { type: 'text/markdown;charset=utf-8' }), `异乡-日记-${Date.now()}.md`);
  }

  async function exportPng() {
    const buckets = collectEntries({
      diaryChoices,
      dreams: dreamEntries,
      insomnias: insomniaEntries,
      nostalgias: nostalgiaEntries,
    });
    const blob = await toPNG(buckets, { week: undefined });
    download(blob, `异乡-日记-${Date.now()}.png`);
  }

  const diaryCover = getMiscImage('diary-cover');
  return (
    <div className="animate-fadein">
      {diaryCover && (
        <div className="relative w-full mb-3 overflow-hidden" style={{ aspectRatio: '2 / 1' }}>
          <img src={diaryCover} alt="" className="w-full h-full object-cover" />
          <div className="absolute inset-0"
            style={{ background: 'linear-gradient(180deg, transparent 60%, rgba(10,8,6,0.8) 100%)' }} />
        </div>
      )}
      <div className="text-xs tracking-[0.2em] opacity-60 mb-2 flex justify-between items-center" style={{ fontFamily: 'monospace' }}>
        <span>📔 日记 · {total} 条</span>
        <span className="flex gap-1">
          <button onClick={exportMd}
            className="px-2 py-1 border border-current/30 hover:border-current/70 hover:bg-current/5 transition-all text-xs"
            title="导出为 Markdown 文件">
            ↓ MD
          </button>
          <button onClick={exportPng}
            className="px-2 py-1 border border-current/30 hover:border-current/70 hover:bg-current/5 transition-all text-xs"
            title="导出为 PNG 图片">
            ↓ PNG
          </button>
        </span>
      </div>

      {/* 分类切换 */}
      <div className="grid grid-cols-3 gap-1 mb-1 text-xs">
        <button onClick={() => setSection('all')}
          className={`py-1.5 border ${section === 'all' ? 'border-current bg-current/10' : 'border-current/30 opacity-60'}`}>
          全部 {total}
        </button>
        <button onClick={() => setSection('achievement')}
          className={`py-1.5 border ${section === 'achievement' ? 'border-amber-300 bg-amber-300/10' : 'border-current/30 opacity-60'}`}
          style={section === 'achievement' ? { color: '#FFD700' } : {}}>
          🎖 成就 {(unlockedAchievements?.length || 0)}
        </button>
        <button onClick={() => setSection('choice')}
          className={`py-1.5 border ${section === 'choice' ? 'border-amber-300/70 bg-amber-300/10' : 'border-current/30 opacity-60'}`}>
          ◆ 决定 {choiceEntries.length}
        </button>
      </div>
      <div className="grid grid-cols-3 gap-1 mb-3 text-xs">
        <button onClick={() => setSection('dream')}
          className={`py-1.5 border ${section === 'dream' ? 'border-purple-300/70 bg-purple-300/10' : 'border-current/30 opacity-60'}`}>
          ☾ 梦 {dreamEntries.length}
        </button>
        <button onClick={() => setSection('insomnia')}
          className={`py-1.5 border ${section === 'insomnia' ? 'border-current bg-current/10' : 'border-current/30 opacity-60'}`}>
          失眠 {insomniaEntries.length}
        </button>
        <button onClick={() => setSection('nostalgia')}
          className={`py-1.5 border ${section === 'nostalgia' ? 'border-red-300/60 bg-red-300/10' : 'border-current/30 opacity-60'}`}>
          🏮 家 {nostalgiaEntries.length}
        </button>
      </div>

      {section === 'achievement' && (
        <AchievementsView unlockedAchievements={unlockedAchievements} gender={gender} gameState={gameState} />
      )}

      {section !== 'achievement' && (
        <div className="space-y-2 max-h-[55vh] overflow-y-auto pr-1">
          {entries.map((e, i) => {
            const ts = typeStyle[e.type];
            return (
              <details key={`${e.type}-${e.id}-${i}`} className="border border-current/20 p-3 group">
                <summary className="cursor-pointer flex items-center gap-2 text-sm">
                  <span style={{ color: ts.color }}>{ts.icon}</span>
                  <span className="flex-1">{e.title}</span>
                  {e.type === 'choice' && e.week && (
                    <span className="text-xs opacity-50 mr-1" style={{ fontFamily: 'monospace' }}>W{e.week}</span>
                  )}
                  <span className="text-xs opacity-50" style={{ fontFamily: 'monospace' }}>{ts.label}</span>
                </summary>
                <div className="mt-3 pl-5 text-sm opacity-85 italic whitespace-pre-line border-l-2 border-current/20"
                  style={{ lineHeight: '2', color: ts.color }}>
                  {e.body}
                </div>
              </details>
            );
          })}
        </div>
      )}
    </div>
  );
}

export function GroupChatView({ groupChat, addedStrangers }) {
  if (groupChat.length === 0) {
    return <div className="text-center opacity-50 italic py-12 text-sm">"伦敦留学生互助"群里还没人说话。</div>;
  }
  const allMembers = [...GROUP_MEMBERS, ...STRANGERS];
  const totalMembers = GROUP_MEMBERS.length + (addedStrangers?.length || 0);
  return (
    <div className="animate-fadein">
      <div className="text-xs tracking-[0.2em] opacity-60 mb-2 flex justify-between" style={{ fontFamily: 'monospace' }}>
        <span>👥 伦敦留学生互助 ({totalMembers})</span>
        <span className="opacity-50">{groupChat.length} 条消息</span>
      </div>
      <div className="space-y-2 max-h-[60vh] overflow-y-auto pr-1">
        {groupChat.map((m) => {
          const member = allMembers.find(g => g.id === m.from);
          if (!member) return null;
          return (
            <div key={m.id} className="flex gap-2 items-start animate-slidein">
              <div className="w-8 h-8 rounded-full flex items-center justify-center text-xs font-medium flex-shrink-0"
                style={{ background: member.color, color: '#1a1612' }}>{member.avatar}</div>
              <div className="flex-1 min-w-0">
                <div className="text-xs opacity-60 mb-0.5" style={{ fontFamily: 'monospace' }}>
                  {member.name} <span className="opacity-50">· W{m.week}</span>
                </div>
                <div className="text-sm bg-current/5 rounded-lg px-3 py-1.5 inline-block max-w-full break-words"
                     style={{ borderLeft: `2px solid ${member.color}40` }}>
                  {m.text}
                </div>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
