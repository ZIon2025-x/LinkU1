import React from 'react';
import { NpcAvatar } from './NpcAvatar.jsx';
import { getSceneForEvent, getNpcImage, MISC_IMAGES } from '../engine/imageRegistry.js';
import { pronounize } from '../engine/pronouns.js';
import { BottomSheet } from './BottomSheet.jsx';
// Modals are mostly self-contained — they receive everything they need via props.

export function EventModal({ event, feedback, onChoose, onDismiss }) {
  const banner = getSceneForEvent(event?.id);
  return (
    <BottomSheet open={true} onClose={onDismiss}
      title={<>EVENT</>}>
      {banner && (
        <div className="relative w-full -mx-5 mb-3" style={{ aspectRatio: '16 / 9' }}>
          <img src={banner} alt="" className="w-full h-full object-cover" />
          <div className="absolute inset-0"
            style={{ background: 'linear-gradient(180deg, transparent 60%, #1a1612 100%)' }} />
        </div>
      )}
      <h2 className="text-xl mb-3 font-light">{event.title}</h2>
      <div className="text-sm leading-relaxed mb-4 opacity-90" style={{ lineHeight: '1.8' }}>
        {event.body}
      </div>
      {event?.id === 'yjie_merger_offer' && MISC_IMAGES['prop-yjie_napkin'] && (
        <div className="mb-4 -mx-2">
          <img src={MISC_IMAGES['prop-yjie_napkin']} alt="Y 姐推过来的那张 napkin"
               className="w-full rounded shadow-md" />
          <div className="text-xs opacity-60 text-center mt-1 italic">— 她推过来的 napkin —</div>
        </div>
      )}
      {!feedback ? (
        (event.choices || [{ label: '继续', effect: event.effect || {}, feedback: event.feedback || '...' }]).map((c, i) => (
          <button key={i} onClick={() => onChoose(c)}
            className="w-full text-left p-3 mb-2 border border-current/40 hover:border-current hover:bg-current/5 active:bg-current/10 transition-all min-h-[44px]">
            <span className="opacity-50 mr-2" style={{ fontFamily: 'monospace' }}>{String.fromCharCode(65+i)}.</span>
            {c.label}
          </button>
        ))
      ) : (
        <>
          <div className="border-l-2 border-current/50 pl-4 py-1 mb-4 italic opacity-90 text-sm" style={{ lineHeight: '1.8' }}>{feedback}</div>
          <button onClick={onDismiss} className="w-full px-6 py-2 border border-current text-sm tracking-[0.2em] hover:bg-current hover:text-black active:bg-current/30 transition-colors min-h-[44px]">CONTINUE</button>
        </>
      )}
    </BottomSheet>
  );
}

export function StoryModal({ chapter, lineName, feedback, onChoose, onDismiss }) {
  return (
    <BottomSheet open={true} onClose={onDismiss}
      title={<span style={{ color: '#d4b070' }}>📖 STORY · {lineName}</span>}>
      <div className="text-xs opacity-50 mb-3" style={{ fontFamily: 'monospace' }}>CHAPTER · {chapter.title}</div>
      <h2 className="text-xl mb-3 font-light">{chapter.title_full}</h2>
      <div className="text-sm leading-relaxed mb-4 opacity-90" style={{ lineHeight: '1.8' }}>{chapter.body}</div>
      {!feedback ? (
        (chapter.choices && chapter.choices.length > 0 ? chapter.choices : [
          { label: '继续', effect: chapter.effect || {}, feedback: chapter.feedback || '...' },
        ]).map((c, i) => (
          <button key={i} onClick={() => onChoose(c)}
            className="w-full text-left p-3 mb-2 border border-current/40 hover:border-current hover:bg-current/5 active:bg-current/10 transition-all min-h-[44px]">
            <span className="opacity-50 mr-2" style={{ fontFamily: 'monospace' }}>{String.fromCharCode(65+i)}.</span>
            {c.label}
          </button>
        ))
      ) : (
        <>
          <div className="border-l-2 border-amber-300/60 pl-4 py-1 mb-4 italic opacity-90 text-sm" style={{ lineHeight: '1.8' }}>{feedback}</div>
          <button onClick={onDismiss} className="w-full px-6 py-2 border border-current text-sm tracking-[0.2em] hover:bg-current hover:text-black active:bg-current/30 transition-colors min-h-[44px]">CONTINUE</button>
        </>
      )}
    </BottomSheet>
  );
}

export function NpcDialogModal({ npc, rel, feedback, onChoose, onDismiss, gender }) {
  // 按性别决定显示的 NPC 名字（linnan 的 "林可儿 / 林楠" → 单名）
  const npcName = pronounize(npc.cn, gender);

  // 动态生成对话选项
  const topics = [
    { label: '寒暄一下', effect: { rel: 1, energy: -1 },
      feedback: `你和${npcName}聊了天气、聊了课。一切如常。` },
    { label: '问问最近怎么样', effect: { rel: 2, energy: -2, belonging: 2 },
      feedback: `${npcName}讲了一些最近的事。你认真听了。这种小小的连接，正是你来这里需要的。` },
  ];

  if (rel >= 3) {
    topics.push({ label: '约 ta 一起做点什么', effect: { rel: 3, energy: -3, belonging: 4 },
      feedback: `${npcName}爽快地答应了。"Sure, let me know when!" 你心里一暖。` });
  }
  if (rel >= 6) {
    topics.push({ label: '聊一些深一点的话题', effect: { rel: 4, energy: -5, belonging: 8 },
      feedback: `你们聊了很久。${npcName}讲了一些以前没讲过的事。你也讲了。这就是友情吧。` });
  }

  return (
    <BottomSheet open={true} onClose={onDismiss}>
      <div className="flex items-center gap-3 mb-4">
        <NpcAvatar npc={npc} gender={gender} size={48} />
        <div>
          <div className="text-lg">{npcName}</div>
          <div className="text-xs opacity-60 italic">{npc.role} · 关系 {rel}</div>
        </div>
      </div>
      <div className="text-sm opacity-80 italic mb-4" style={{ lineHeight: '1.7' }}>{npc.bio}</div>
      {!feedback ? (
        <>
          <div className="text-xs opacity-60 mb-2" style={{ fontFamily: 'monospace' }}>选个话题</div>
          {topics.map((t, i) => (
            <button key={i} onClick={() => onChoose(t)}
              className="w-full text-left p-2.5 mb-2 border border-current/40 hover:border-current hover:bg-current/5 active:bg-current/10 transition-all text-sm">
              {t.label}
            </button>
          ))}
          <button onClick={onDismiss} className="w-full mt-2 p-2 text-xs opacity-60 hover:opacity-100 active:opacity-90">
            先这样吧 →
          </button>
        </>
      ) : (
        <>
          <div className="border-l-2 border-current/50 pl-4 py-1 mb-4 italic opacity-90 text-sm" style={{ lineHeight: '1.8' }}>{feedback}</div>
          <button onClick={onDismiss} className="w-full px-6 py-2 border border-current text-sm tracking-[0.2em] hover:bg-current hover:text-black active:bg-current/30 transition-colors">CONTINUE</button>
        </>
      )}
    </BottomSheet>
  );
}

export function StrangerEncounterModal({ stranger, onAdd, onReject }) {
  const strangerImg = getNpcImage(stranger.id);
  return (
    <BottomSheet open={true} onClose={onReject}>
      <div className="text-xs tracking-[0.3em] opacity-50 mb-1" style={{ fontFamily: 'monospace' }}>📱 偶遇</div>
      <h2 className="text-xl mb-1 font-light">{stranger.encounterTitle}</h2>
      <div className="text-sm leading-relaxed mb-5 opacity-90 whitespace-pre-line" style={{ lineHeight: '1.85' }}>
        {stranger.encounterBody}
      </div>

      <div className="flex items-center gap-3 px-3 py-2 mb-4 border border-current/20 bg-current/5">
        {strangerImg ? (
          <img src={strangerImg} alt="" className="w-9 h-9 rounded-full object-cover flex-shrink-0" />
        ) : (
          <div className="w-9 h-9 rounded-full flex items-center justify-center text-sm font-medium flex-shrink-0"
            style={{ background: stranger.color, color: '#1a1612' }}>{stranger.avatar}</div>
        )}
        <div className="flex-1 min-w-0">
          <div className="text-sm">{stranger.name}</div>
          <div className="text-xs opacity-60 italic" style={{ fontFamily: 'monospace' }}>{stranger.role}</div>
        </div>
      </div>

      <div className="space-y-2">
        <button onClick={() => onAdd(stranger)}
          className="w-full text-left p-3 border border-amber-300/50 hover:border-amber-300 hover:bg-amber-300/5 active:bg-amber-300/10 transition-all">
          <div className="text-sm">扫码加好友 · 拉进群</div>
          <div className="text-xs opacity-60 italic mt-0.5">+1 群成员 · +少量归属感</div>
        </button>
        <button onClick={onReject}
          className="w-full text-left p-3 border border-current/30 hover:border-current/60 active:bg-current/5 transition-all">
          <div className="text-sm">"今天有点忙 改天" 客气拒绝</div>
          <div className="text-xs opacity-60 italic mt-0.5">下次可能就遇不到了</div>
        </button>
      </div>
    </BottomSheet>
  );
}

export function AtYouModal({ event, members, strangers, feedback, onChoose, onDismiss }) {
  const member = (members || []).find(g => g.id === event.askerId)
              || (strangers || []).find(s => s.id === event.askerId);
  return (
    <BottomSheet open={true} onClose={onDismiss}>
      <div className="text-xs tracking-[0.3em] mb-1" style={{ fontFamily: 'monospace', color: '#d49060' }}>👥 群里有人 @ 你</div>
      <div className="text-xs opacity-60 italic mb-3" style={{ fontFamily: 'monospace' }}>{event.setup}</div>

      {/* 群消息气泡 */}
      {member && (
        <div className="flex gap-2 items-start mb-4 p-3 bg-current/5 rounded">
          <div className="w-8 h-8 rounded-full flex items-center justify-center text-xs font-medium flex-shrink-0"
            style={{ background: member.color, color: '#1a1612' }}>{member.avatar}</div>
          <div className="flex-1 min-w-0">
            <div className="text-xs opacity-60 mb-0.5" style={{ fontFamily: 'monospace' }}>{member.name}</div>
            <div className="text-sm" style={{ lineHeight: '1.6' }}>{event.askerMsg}</div>
          </div>
        </div>
      )}

      {!feedback ? (
        <>
          <div className="text-xs tracking-[0.2em] opacity-60 mb-2" style={{ fontFamily: 'monospace' }}>怎么回？</div>
          <div className="space-y-2">
            {event.choices.map((c, i) => (
              <button key={i} onClick={() => onChoose(c)}
                className="w-full text-left p-3 border border-current/40 hover:border-orange-300 hover:bg-orange-300/5 active:bg-orange-300/10 transition-all">
                <div className="text-sm">{c.label}</div>
              </button>
            ))}
          </div>
        </>
      ) : (
        <>
          <div className="border-l-2 border-orange-300/60 pl-4 py-1 mb-4 italic opacity-90 text-sm whitespace-pre-line" style={{ lineHeight: '1.85' }}>
            {feedback}
          </div>
          <button onClick={onDismiss} className="w-full px-6 py-2 border border-current text-sm tracking-[0.2em] hover:bg-current hover:text-black active:bg-current/30 transition-colors">
            CONTINUE
          </button>
        </>
      )}
    </BottomSheet>
  );
}
export function DreamModal({ dream, onDismiss }) {
  return (
    <BottomSheet open={true} onClose={onDismiss}>
      <div className="text-xs tracking-[0.4em] mb-2" style={{ fontFamily: 'monospace', color: '#a89cc0' }}>
        ☾ 凌晨 · 一场梦
      </div>
      <h2 className="text-xl mb-4 font-light italic" style={{ color: '#c8b8e0' }}>{dream.title}</h2>
      <div className="text-sm leading-relaxed mb-6 opacity-85 whitespace-pre-line italic" style={{ lineHeight: '2', color: '#d8d0e8' }}>
        {dream.body}
      </div>
      <button onClick={onDismiss}
        className="w-full px-6 py-2 border border-purple-300/40 text-sm tracking-[0.2em] hover:bg-purple-300/10 active:bg-purple-300/15 transition-colors"
        style={{ color: '#c8b8e0' }}>
        醒来
      </button>
    </BottomSheet>
  );
}

export function InsomniaModal({ thought, onDismiss }) {
  return (
    <BottomSheet open={true} onClose={onDismiss}>
      <div className="text-xs tracking-[0.4em] mb-2 opacity-60" style={{ fontFamily: 'monospace' }}>☾ 失眠</div>
      <h2 className="text-xl mb-4 font-light italic opacity-90">{thought.title}</h2>
      <div className="text-sm leading-relaxed mb-6 opacity-80 whitespace-pre-line" style={{ lineHeight: '2.1' }}>
        {thought.body}
      </div>
      <button onClick={onDismiss}
        className="w-full px-6 py-2 border border-current/40 text-sm tracking-[0.2em] hover:bg-current/10 active:bg-current/15 transition-colors opacity-80">
        天亮了
      </button>
      <div className="text-xs opacity-40 italic mt-3 text-center">+5 精力 · -3 归属</div>
    </BottomSheet>
  );
}

export function NostalgiaModal({ moment, onDismiss }) {
  return (
    <BottomSheet open={true} onClose={onDismiss}>
      <div className="text-xs tracking-[0.4em] mb-2" style={{ fontFamily: 'monospace', color: '#c89090' }}>
        🏮 想家
      </div>
      <h2 className="text-xl mb-4 font-light italic" style={{ color: '#e8c8c0' }}>{moment.title}</h2>
      <div className="text-sm leading-relaxed mb-6 opacity-90 whitespace-pre-line" style={{ lineHeight: '2', color: '#e0d0c8' }}>
        {moment.body}
      </div>
      <button onClick={onDismiss}
        className="w-full px-6 py-2 border border-red-300/30 text-sm tracking-[0.2em] hover:bg-red-300/5 active:bg-red-300/10 transition-colors"
        style={{ color: '#e8c8c0' }}>
        继续
      </button>
      <div className="text-xs opacity-40 italic mt-3 text-center">-8 归属 · 但下次给妈妈打电话会更有意义</div>
    </BottomSheet>
  );
}

export function ParentsChapterModal({ chapter, feedback, onChoose, onDismiss }) {
  const totalChapters = 5;
  return (
    <BottomSheet open={true} onClose={onDismiss}>
      <div className="flex justify-between items-baseline mb-2">
        <div className="text-xs tracking-[0.4em]" style={{ fontFamily: 'monospace', color: '#d4b070' }}>
          🇨🇳 父母 · 第 {chapter.chapter} 章 / 共 {totalChapters} 章
        </div>
      </div>
      <h2 className="text-2xl mb-1 font-light" style={{ color: '#f0d8b0' }}>{chapter.title}</h2>
      <div className="flex gap-1 mb-5">
        {[...Array(totalChapters)].map((_, i) => (
          <div key={i} className={`flex-1 h-0.5 ${i < chapter.chapter ? 'bg-amber-300/70' : 'bg-current/20'}`} />
        ))}
      </div>

      <div className="text-sm leading-relaxed mb-6 opacity-95 whitespace-pre-line" style={{ lineHeight: '2.05', color: '#e0d4c0' }}>
        {chapter.body}
      </div>

      {!feedback ? (
        <div className="space-y-2">
          {chapter.choices.map((c, i) => (
            <button key={i} onClick={() => onChoose(c)}
              className="w-full text-left p-3 border border-amber-300/40 hover:border-amber-300 hover:bg-amber-300/5 active:bg-amber-300/10 transition-all text-sm"
              style={{ lineHeight: '1.6' }}>
              {c.label}
            </button>
          ))}
        </div>
      ) : (
        <>
          <div className="border-l-2 border-amber-300/60 pl-4 py-1 mb-4 italic opacity-95 text-sm whitespace-pre-line"
            style={{ lineHeight: '2.05', color: '#e8d4b8' }}>
            {feedback}
          </div>
          <button onClick={onDismiss}
            className="w-full px-6 py-2.5 border border-amber-300/60 text-sm tracking-[0.2em] hover:bg-amber-300/10 active:bg-amber-300/15 transition-colors"
            style={{ color: '#f0d8b0' }}>
            {chapter.chapter === 5 ? '走出 Heathrow' : 'CONTINUE'}
          </button>
        </>
      )}
    </BottomSheet>
  );
}
export function StrangerEventModal({ event, strangers, feedback, onChoose, onDismiss }) {
  const stranger = strangers.find(s => s.id === event.strangerId);
  const strangerImg = stranger ? getNpcImage(stranger.id) : null;
  return (
    <BottomSheet open={true} onClose={onDismiss}>
      <div className="text-xs tracking-[0.3em] mb-1 opacity-60" style={{ fontFamily: 'monospace' }}>📱 群里的朋友</div>
      <h2 className="text-xl mb-3 font-light">{event.title}</h2>

      {stranger && (
        <div className="flex items-center gap-2 mb-3 px-3 py-2 border border-current/20 bg-current/5">
          {strangerImg ? (
            <img src={strangerImg} alt="" className="w-8 h-8 rounded-full object-cover flex-shrink-0" />
          ) : (
            <div className="w-8 h-8 rounded-full flex items-center justify-center text-xs font-medium flex-shrink-0"
              style={{ background: stranger.color, color: '#1a1612' }}>{stranger.avatar}</div>
          )}
          <div className="text-xs">
            <div>{stranger.name}</div>
            <div className="opacity-60 italic" style={{ fontFamily: 'monospace' }}>{stranger.role}</div>
          </div>
        </div>
      )}

      <div className="text-sm leading-relaxed mb-5 opacity-90 whitespace-pre-line" style={{ lineHeight: '1.85' }}>
        {event.body}
      </div>

      {!feedback ? (
        <div className="space-y-2">
          {event.choices.map((c, i) => (
            <button key={i} onClick={() => onChoose(c)}
              className="w-full text-left p-3 border border-current/40 hover:border-current hover:bg-current/5 active:bg-current/10 transition-all text-sm">
              <span className="opacity-50 mr-2" style={{ fontFamily: 'monospace' }}>{String.fromCharCode(65 + i)}.</span>
              {c.label}
            </button>
          ))}
        </div>
      ) : (
        <>
          <div className="border-l-2 border-current/50 pl-4 py-1 mb-4 italic opacity-90 text-sm whitespace-pre-line" style={{ lineHeight: '1.85' }}>
            {feedback}
          </div>
          <button onClick={onDismiss} className="w-full px-6 py-2 border border-current text-sm tracking-[0.2em] hover:bg-current hover:text-black active:bg-current/30 transition-colors">
            CONTINUE
          </button>
        </>
      )}
    </BottomSheet>
  );
}

export function CrisisModal({ crisis, feedback, onChoose, onDismiss }) {
  return (
    <BottomSheet open={true} onClose={onDismiss}>
      <div className="text-xs tracking-[0.4em] mb-2" style={{ fontFamily: 'monospace', color: '#d49090' }}>
        ⚠️ 4:38 AM
      </div>
      <h2 className="text-xl mb-4 font-light italic" style={{ color: '#e8b8b8' }}>{crisis.title}</h2>
      <div className="text-sm leading-relaxed mb-6 opacity-90 whitespace-pre-line italic" style={{ lineHeight: '2', color: '#e0c8c8' }}>
        {crisis.body}
      </div>

      {!feedback ? (
        <div className="space-y-2">
          <button onClick={() => onChoose({ id: 'quit' })}
            className="w-full text-left p-3 border border-red-400/40 hover:border-red-400 hover:bg-red-400/5 active:bg-red-400/10 transition-all text-sm"
            style={{ color: '#e8b8b8' }}>
            <div>现在就订机票回国</div>
            <div className="text-xs opacity-60 italic mt-0.5">这是终结这一年的方式</div>
          </button>
          <button onClick={() => onChoose({ id: 'persist' })}
            className="w-full text-left p-3 border border-current/40 hover:border-current/70 active:bg-current/5 transition-all text-sm">
            <div>"再坚持一周看看"</div>
            <div className="text-xs opacity-60 italic mt-0.5">放下手机，睡觉</div>
          </button>
          <button onClick={() => onChoose({ id: 'call_mom' })}
            className="w-full text-left p-3 border border-amber-300/40 hover:border-amber-300 hover:bg-amber-300/5 active:bg-amber-300/10 transition-all text-sm">
            <div>给妈妈打个电话</div>
            <div className="text-xs opacity-60 italic mt-0.5">中国是中午 12:38</div>
          </button>
        </div>
      ) : (
        <>
          <div className="border-l-2 border-red-400/40 pl-4 py-1 mb-4 italic opacity-90 text-sm whitespace-pre-line" style={{ lineHeight: '2' }}>
            {feedback}
          </div>
          <button onClick={onDismiss} className="w-full px-6 py-2 border border-current text-sm tracking-[0.2em] hover:bg-current hover:text-black active:bg-current/30 transition-colors">
            天亮了
          </button>
        </>
      )}
    </BottomSheet>
  );
}
export function TravelEventModal({ event, feedback, onChoose, onDismiss }) {
  return (
    <BottomSheet open={true} onClose={onDismiss}>
      <div className="text-xs tracking-[0.3em] mb-1" style={{ fontFamily: 'monospace', color: '#d4b070' }}>
        ✈️ TRAVEL EVENT
      </div>
      <h2 className="text-xl mb-3 font-light">{event.title}</h2>
      <div className="text-sm leading-relaxed mb-5 opacity-90 whitespace-pre-line" style={{ lineHeight: '1.85' }}>
        {event.body}
      </div>

      {!feedback ? (
        <>
          {(event.choices || [{
            label: event.title.length > 12 ? '继续' : `去${event.title}`,
            effect: event.effect || {},
            feedback: event.feedback || '...'
          }]).map((c, i) => (
            <button key={i} onClick={() => onChoose(c)}
              className="w-full text-left p-3 mb-2 border border-current/40 hover:border-amber-300 hover:bg-amber-300/5 active:bg-amber-300/10 transition-all">
              <span className="opacity-50 mr-2" style={{ fontFamily: 'monospace' }}>{String.fromCharCode(65 + i)}.</span>
              {c.label}
            </button>
          ))}
        </>
      ) : (
        <>
          <div className="border-l-2 border-amber-300/60 pl-4 py-1 mb-4 italic opacity-90 text-sm whitespace-pre-line" style={{ lineHeight: '1.85' }}>{feedback}</div>
          {event.postcard && (
            <div className="mb-4 px-3 py-2 border border-amber-300/40 bg-amber-300/5 text-center">
              <div className="text-xs opacity-60 mb-1" style={{ fontFamily: 'monospace' }}>✉️ NEW POSTCARD</div>
              <div className="text-sm italic" style={{ color: '#d4b070' }}>"{event.postcard}"</div>
            </div>
          )}
          <button onClick={onDismiss} className="w-full px-6 py-2 border border-current text-sm tracking-[0.2em] hover:bg-current hover:text-black active:bg-current/30 transition-colors">
            CONTINUE
          </button>
        </>
      )}
    </BottomSheet>
  );
}
