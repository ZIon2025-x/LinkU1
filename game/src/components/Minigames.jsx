import React, { useState, useEffect, useRef } from 'react';
import { audio } from '../engine/audio.js';
import {
  YELLOW_LABEL_ITEMS, PRET_QUESTIONS, ESSAY_PUZZLES, THEORIST_MATCH,
} from '../data/index.js';

export function YellowLabelMinigame({ onComplete, feedback, onDismiss }) {
  const [phase, setPhase] = useState('ready'); // ready | playing | done
  const [items, setItems] = useState([]);
  const [grabbed, setGrabbed] = useState([]);
  const [timeLeft, setTimeLeft] = useState(5);
  const timerRef = useRef(null);

  function start() {
    audio.click();
    // 随机洗牌商品
    const shuffled = [...YELLOW_LABEL_ITEMS].sort(() => Math.random() - 0.5);
    setItems(shuffled);
    setGrabbed([]);
    setTimeLeft(5);
    setPhase('playing');
    timerRef.current = setInterval(() => {
      setTimeLeft(t => {
        if (t <= 1) {
          clearInterval(timerRef.current);
          setPhase('done');
          return 0;
        }
        return t - 1;
      });
    }, 1000);
  }

  function grab(item, idx) {
    if (phase !== 'playing') return;
    if (grabbed.includes(idx)) return;
    audio.click();
    setGrabbed([...grabbed, idx]);
  }

  function finish() {
    if (phase !== 'done') {
      clearInterval(timerRef.current);
      setPhase('done');
    }
    const yellow = grabbed.filter(idx => items[idx]?.isYellow);
    const wrong = grabbed.filter(idx => !items[idx]?.isYellow);
    const totalSavings = yellow.reduce((s, idx) => s + items[idx].price, 0);
    const totalCost = grabbed.reduce((s, idx) => s + items[idx].price, 0);
    const result = {
      success: yellow.length >= 2 && wrong.length === 0,
      cost: totalCost,
      energy: yellow.length * 2 - wrong.length,
      belonging: yellow.length >= 2 ? 3 : 0,
      feedback: yellow.length >= 2 && wrong.length === 0
        ? `你抢到了 ${yellow.length} 件黄标商品！总共花了 £${totalCost}。其他亚洲面孔向你点了点头，某种隐秘的同盟。`
        : wrong.length > 0
        ? `你抢到了一些东西，但有 ${wrong.length} 件不是黄标。你看了看小票：£${totalCost}。算了，回家煮泡面。`
        : `你什么都没抢到。回家路上下起了雨。`,
    };
    onComplete(result);
  }

  useEffect(() => () => clearInterval(timerRef.current), []);

  return (
    <div className="fixed inset-0 z-40 flex items-center justify-center p-4" style={{ background: 'rgba(10, 8, 6, 0.9)' }}>
      <div className="bg-[#1a1612] border border-current/40 max-w-md w-full p-5 animate-fadein">
        <div className="text-xs tracking-[0.3em] opacity-50 mb-2" style={{ fontFamily: 'monospace' }}>MINIGAME</div>
        <h2 className="text-xl mb-3 font-light">🛒 抢黄标</h2>

        {phase === 'ready' && (
          <>
            <div className="text-sm opacity-90 mb-4" style={{ lineHeight: '1.8' }}>
              晚上 9 点。Tesco 员工推着小车出来。<br/>
              5 秒内点击带 <span style={{ color: '#d4b070' }}>黄标</span> 的商品（贴纸为黄色的）。<br/>
              <span className="opacity-60 italic text-xs">⚠️ 别抢错了，原价的会扣钱。</span>
            </div>
            <button onClick={start} className="w-full py-3 border border-current hover:bg-current hover:text-black transition-colors tracking-[0.2em] text-sm">
              开始
            </button>
            <button onClick={onDismiss} className="w-full mt-2 p-2 text-xs opacity-60 hover:opacity-100">放弃 →</button>
          </>
        )}

        {phase === 'playing' && (
          <>
            <div className="flex justify-between mb-3 items-center">
              <div className="text-sm opacity-80">已抢 {grabbed.length}</div>
              <div className="text-2xl" style={{ fontFamily: 'monospace', color: timeLeft <= 2 ? '#c86060' : '#e8e0d0' }}>{timeLeft}</div>
            </div>
            <div className="grid grid-cols-3 gap-2">
              {items.map((item, idx) => {
                const taken = grabbed.includes(idx);
                return (
                  <button key={idx} onClick={() => grab(item, idx)} disabled={taken}
                    className={`relative aspect-square border ${taken ? 'border-current/20 opacity-30' : 'border-current/40 hover:border-current hover:bg-current/5'} transition-all flex flex-col items-center justify-center`}>
                    {item.isYellow && !taken && (
                      <div className="absolute top-1 right-1 px-1 text-[8px]" style={{ background: '#d4b070', color: '#1a1612', fontFamily: 'monospace' }}>£{item.price}</div>
                    )}
                    <div className="text-3xl">{item.emoji}</div>
                    <div className="text-xs mt-1 opacity-70">{item.name}</div>
                  </button>
                );
              })}
            </div>
            <button onClick={finish} className="w-full mt-3 py-2 border border-current/40 text-xs tracking-[0.2em] hover:bg-current/10 transition-all">
              停手 →
            </button>
          </>
        )}

        {phase === 'done' && !feedback && (
          <>
            <div className="text-sm opacity-90 mb-4" style={{ lineHeight: '1.8' }}>
              时间到。你抢到了 {grabbed.length} 件商品。
            </div>
            <button onClick={finish} className="w-full py-3 border border-current hover:bg-current hover:text-black transition-colors tracking-[0.2em] text-sm">
              查看结果
            </button>
          </>
        )}

        {feedback && (
          <>
            <div className="border-l-2 border-current/50 pl-4 py-1 mb-4 italic opacity-90 text-sm" style={{ lineHeight: '1.8' }}>{feedback}</div>
            <button onClick={onDismiss} className="w-full px-6 py-2 border border-current text-sm tracking-[0.2em] hover:bg-current hover:text-black transition-colors">CONTINUE</button>
          </>
        )}
      </div>
    </div>
  );
}
export function PretMinigame({ onComplete, onCancel }) {
  const [phase, setPhase] = useState('intro');
  const [currentQ, setCurrentQ] = useState(0);
  const [answers, setAnswers] = useState([]);
  const [showFeedback, setShowFeedback] = useState(null);

  function start() { audio.click(); setPhase('quiz'); }

  function answer(opt, optIdx) {
    audio.click();
    if (opt.correct) audio.success(); else audio.fail();
    setShowFeedback(opt);
    const newAns = [...answers, { q: currentQ, picked: optIdx, correct: opt.correct }];
    setAnswers(newAns);
  }

  function nextQ() {
    audio.click();
    setShowFeedback(null);
    if (currentQ + 1 < PRET_QUESTIONS.length) {
      setCurrentQ(currentQ + 1);
    } else {
      setPhase('done');
    }
  }

  function done() {
    audio.click();
    const correctCount = answers.filter(a => a.correct).length;
    const result = {
      score: correctCount,
      total: PRET_QUESTIONS.length,
      effect: {
        wallet: -5,
        energy: correctCount >= 4 ? 5 : -3,
        belonging: correctCount >= 4 ? 6 : correctCount >= 3 ? 2 : -3,
      },
      feedback: correctCount >= 4
        ? `你拿到咖啡走出 Pret，回头店员还在跟你笑。${correctCount}/5 答对——你这周第一次觉得，英语不再是一道墙。`
        : correctCount >= 3
        ? `你拿到了咖啡。咖啡比平时凉了一点，你猜是因为你站在那里太久了。${correctCount}/5。`
        : `你拿到了咖啡，但你在路上走了 5 分钟才想起这次的对话每一句都说得磕磕绊绊。${correctCount}/5。明天还得继续。`,
    };
    onComplete(result);
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 animate-fadein" style={{ background: 'rgba(10, 8, 6, 0.95)' }}>
      <div className="bg-[#1a1612] border border-current/40 max-w-md w-full p-5">
        <div className="text-xs tracking-[0.3em] opacity-50 mb-2" style={{ fontFamily: 'monospace' }}>☕ MINIGAME</div>
        <h2 className="text-xl mb-1 font-light">Pret 点餐</h2>
        <div className="text-xs opacity-60 italic mb-4" style={{ fontFamily: 'monospace' }}>5 句对话 · 你能听懂多少？</div>

        {phase === 'intro' && (
          <>
            <div className="text-sm opacity-90 mb-5" style={{ lineHeight: '1.85' }}>
              <p>中午 12:30 的 Pret。后面排了 6 个英国人，他们都很赶时间。</p>
              <p className="mt-3">店员看着你："What can I get you, love?"</p>
            </div>
            <button onClick={start} className="w-full py-3 border border-current hover:bg-current hover:text-black transition-colors tracking-[0.2em] text-sm">
              点单
            </button>
            <button onClick={onCancel} className="w-full mt-2 p-2 text-xs opacity-60 hover:opacity-100">逃出去 →</button>
          </>
        )}

        {phase === 'quiz' && !showFeedback && (
          <>
            <div className="text-xs opacity-60 mb-2" style={{ fontFamily: 'monospace' }}>第 {currentQ + 1} 句 / 共 5 句</div>
            <div className="border-l-2 border-current/50 pl-4 py-2 mb-4 italic text-base" style={{ lineHeight: '1.6' }}>
              <span className="opacity-60 text-xs not-italic mr-2">店员：</span>
              {PRET_QUESTIONS[currentQ].staff}
            </div>
            <div className="space-y-2">
              {PRET_QUESTIONS[currentQ].options.map((opt, i) => (
                <button key={i} onClick={() => answer(opt, i)}
                  className="w-full text-left p-3 border border-current/40 hover:border-current hover:bg-current/5 transition-all text-sm">
                  {opt.text}
                </button>
              ))}
            </div>
          </>
        )}

        {showFeedback && (
          <>
            <div className={`p-3 mb-4 border-l-2 italic text-sm ${showFeedback.correct ? 'border-green-400/60 text-green-200' : 'border-orange-400/60 text-orange-200'}`}
              style={{ lineHeight: '1.7' }}>
              {showFeedback.correct ? '✓ ' : '✗ '}{showFeedback.feedback}
            </div>
            <button onClick={nextQ} className="w-full py-2 border border-current text-sm tracking-[0.2em] hover:bg-current hover:text-black transition-colors">
              {currentQ + 1 < PRET_QUESTIONS.length ? 'NEXT' : '看结果'}
            </button>
          </>
        )}

        {phase === 'done' && (
          <>
            <div className="text-center my-6">
              <div className="text-xs opacity-60 mb-1" style={{ fontFamily: 'monospace' }}>YOUR SCORE</div>
              <div className="text-5xl font-light" style={{ fontFamily: 'monospace',
                color: answers.filter(a => a.correct).length >= 4 ? '#a0c890' : '#d4b070' }}>
                {answers.filter(a => a.correct).length}/{PRET_QUESTIONS.length}
              </div>
            </div>
            <button onClick={done} className="w-full py-2 border border-current text-sm tracking-[0.2em] hover:bg-current hover:text-black transition-colors">
              CONTINUE
            </button>
          </>
        )}
      </div>
    </div>
  );
}

// ========================================
// 论文写作迷你游戏
// ========================================

export function EssayMinigame({ onComplete, onCancel }) {
  const [puzzleIdx, setPuzzleIdx] = useState(0);
  const [pickedIdx, setPickedIdx] = useState(null);
  const [score, setScore] = useState(0);
  const [showFb, setShowFb] = useState(null);

  const puzzle = ESSAY_PUZZLES[puzzleIdx];

  function pick(idx) {
    audio.click();
    setPickedIdx(idx);
    const opt = puzzle.options[idx];
    if (opt.correct) { audio.success(); setScore(score + 1); }
    else audio.fail();
    setShowFb(opt);
  }

  function next() {
    audio.click();
    setShowFb(null);
    setPickedIdx(null);
    if (puzzleIdx + 1 < ESSAY_PUZZLES.length) {
      setPuzzleIdx(puzzleIdx + 1);
    } else {
      finish();
    }
  }

  function finish() {
    audio.click();
    const finalScore = score + (showFb?.correct ? 0 : 0); // already counted
    onComplete({
      score: finalScore,
      total: ESSAY_PUZZLES.length,
      effect: {
        academic: finalScore * 4,
        energy: -8,
        belonging: finalScore >= 2 ? 3 : 0,
      },
      feedback: finalScore === 3
        ? '你写完这一段时已经凌晨 2 点。Whitmore 第二天看完邮件回了一句："This is publishable."'
        : finalScore >= 2
        ? '你写出来了。不完美，但每一句都是你自己的。Whitmore 写："Good progress."'
        : '你 4 个小时只写了一段，最后还是删了一半。但你坐下来过了——这就是写作的开始。',
    });
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 animate-fadein" style={{ background: 'rgba(10, 8, 6, 0.95)' }}>
      <div className="bg-[#1a1612] border border-purple-300/40 max-w-md w-full p-5">
        <div className="text-xs tracking-[0.3em] mb-1" style={{ fontFamily: 'monospace', color: '#9080b8' }}>📝 MINIGAME</div>
        <h2 className="text-xl mb-1 font-light">写论文</h2>
        <div className="text-xs opacity-60 italic mb-4" style={{ fontFamily: 'monospace' }}>填入最合适的句子 · {puzzleIdx + 1}/3</div>

        {!showFb ? (
          <>
            <div className="text-xs tracking-[0.2em] opacity-60 mb-2" style={{ fontFamily: 'monospace' }}>{puzzle.context}</div>
            <div className="border-l-2 border-purple-300/40 pl-4 py-2 mb-4 text-sm italic bg-purple-300/5"
              style={{ lineHeight: '1.85' }}>
              {puzzle.paragraph.split('___').map((part, i, arr) => (
                <span key={i}>
                  {part}
                  {i < arr.length - 1 && (
                    <span className="inline-block px-3 mx-1 py-0.5 border border-dashed border-purple-300/60 rounded text-xs opacity-80" style={{ color: '#9080b8' }}>
                      ?
                    </span>
                  )}
                </span>
              ))}
            </div>
            <div className="space-y-2">
              {puzzle.options.map((opt, i) => (
                <button key={i} onClick={() => pick(i)}
                  className="w-full text-left p-3 border border-current/40 hover:border-purple-300 hover:bg-purple-300/5 transition-all text-sm"
                  style={{ lineHeight: '1.6' }}>
                  {opt.text}
                </button>
              ))}
            </div>
            <button onClick={onCancel} className="w-full mt-3 p-2 text-xs opacity-60 hover:opacity-100">放弃 →</button>
          </>
        ) : (
          <>
            <div className={`p-3 mb-4 border-l-2 italic text-sm ${showFb.correct ? 'border-green-400/60' : 'border-orange-400/60'}`}
              style={{ lineHeight: '1.85' }}>
              {showFb.feedback}
            </div>
            <button onClick={next} className="w-full py-2 border border-current text-sm tracking-[0.2em] hover:bg-current hover:text-black transition-colors">
              {puzzleIdx + 1 < ESSAY_PUZZLES.length ? 'NEXT' : '完成'}
            </button>
          </>
        )}
      </div>
    </div>
  );
}

// ========================================
// 理论家概念匹配迷你游戏
// ========================================

export function MatchMinigame({ onComplete, onCancel }) {
  // 每次随机抽 6 个概念
  const [round] = useState(() => {
    const allConcepts = Object.entries(THEORIST_MATCH.concepts);
    const shuffled = allConcepts.sort(() => Math.random() - 0.5).slice(0, 6);
    return shuffled.map(([id, c]) => ({ id, ...c }));
  });
  const [matched, setMatched] = useState({}); // { conceptId: theoristId }
  const [selectedConcept, setSelectedConcept] = useState(null);
  const [phase, setPhase] = useState('play'); // play | done

  function selectConcept(c) {
    if (matched[c.id]) return;
    audio.click();
    setSelectedConcept(c.id);
  }

  function selectTheorist(t) {
    if (!selectedConcept) return;
    audio.click();
    setMatched({ ...matched, [selectedConcept]: t.id });
    setSelectedConcept(null);
    if (Object.keys({ ...matched, [selectedConcept]: t.id }).length === round.length) {
      setTimeout(() => setPhase('done'), 300);
    }
  }

  function done() {
    audio.click();
    let correct = 0;
    Object.entries(matched).forEach(([cid, tid]) => {
      const theorist = THEORIST_MATCH.theorists.find(t => t.id === tid);
      if (theorist?.concepts.includes(cid)) correct++;
    });
    if (correct >= 5) audio.success(); else if (correct >= 3) audio.click(); else audio.fail();
    onComplete({
      score: correct,
      total: round.length,
      effect: {
        academic: correct * 2,
        energy: -5,
        belonging: correct >= 5 ? 3 : 0,
      },
      feedback: correct === 6
        ? `${correct}/6 全对。Aditi 路过看你的笔记本，竖了个大拇指："I knew you knew this stuff."`
        : correct >= 4
        ? `${correct}/6。算可以。这种基础知识是你的护城河。`
        : `${correct}/6。你看着自己写错的，意识到 reading list 不能再拖了。`,
    });
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 animate-fadein" style={{ background: 'rgba(10, 8, 6, 0.95)' }}>
      <div className="bg-[#1a1612] border border-blue-300/40 max-w-md w-full max-h-[90vh] overflow-y-auto p-5">
        <div className="text-xs tracking-[0.3em] mb-1" style={{ fontFamily: 'monospace', color: '#a0a0c8' }}>🎴 MINIGAME</div>
        <h2 className="text-xl mb-1 font-light">理论家与概念</h2>
        <div className="text-xs opacity-60 italic mb-4" style={{ fontFamily: 'monospace' }}>把概念匹配到对的人</div>

        {phase === 'play' && (
          <>
            <div className="text-xs opacity-60 mb-2" style={{ fontFamily: 'monospace' }}>
              {selectedConcept ? '选一个理论家 →' : '选一个概念 →'}
            </div>

            {/* 概念区 */}
            <div className="grid grid-cols-2 gap-2 mb-4">
              {round.map(c => {
                const isMatched = !!matched[c.id];
                const isSelected = selectedConcept === c.id;
                return (
                  <button key={c.id} onClick={() => selectConcept(c)} disabled={isMatched}
                    className={`p-2 border text-left transition-all ${
                      isMatched ? 'border-current/10 opacity-30' :
                      isSelected ? 'border-blue-300 bg-blue-300/10' :
                      'border-current/40 hover:border-current/70'
                    }`}>
                    <div className="text-sm">{c.label}</div>
                    <div className="text-xs opacity-60 italic">{c.desc}</div>
                  </button>
                );
              })}
            </div>

            {/* 理论家区 */}
            <div className="border-t border-current/20 pt-3">
              <div className="text-xs opacity-60 mb-2" style={{ fontFamily: 'monospace' }}>理论家</div>
              <div className="grid grid-cols-2 gap-2">
                {THEORIST_MATCH.theorists.map(t => {
                  const matchedToThis = Object.entries(matched).filter(([_, tid]) => tid === t.id).map(([cid]) => cid);
                  return (
                    <button key={t.id} onClick={() => selectTheorist(t)} disabled={!selectedConcept}
                      className={`p-2 border text-left transition-all ${
                        selectedConcept ? 'border-blue-300/60 hover:bg-blue-300/10' : 'border-current/30 opacity-50 cursor-not-allowed'
                      }`}>
                      <div className="text-sm font-medium">{t.name}</div>
                      {matchedToThis.length > 0 && (
                        <div className="text-xs opacity-60 italic mt-0.5">
                          {matchedToThis.map(cid => THEORIST_MATCH.concepts[cid]?.label).join(', ')}
                        </div>
                      )}
                    </button>
                  );
                })}
              </div>
            </div>
            <button onClick={onCancel} className="w-full mt-3 p-2 text-xs opacity-60 hover:opacity-100">先不玩 →</button>
          </>
        )}

        {phase === 'done' && (
          <>
            <div className="text-center my-4">
              <div className="text-xs opacity-60 mb-1" style={{ fontFamily: 'monospace' }}>SCORE</div>
              <div className="text-4xl font-light" style={{ fontFamily: 'monospace' }}>
                {Object.entries(matched).filter(([cid, tid]) => {
                  const t = THEORIST_MATCH.theorists.find(t2 => t2.id === tid);
                  return t?.concepts.includes(cid);
                }).length}/{round.length}
              </div>
            </div>
            <div className="space-y-1 text-xs mb-4">
              {Object.entries(matched).map(([cid, tid]) => {
                const concept = THEORIST_MATCH.concepts[cid];
                const theorist = THEORIST_MATCH.theorists.find(t => t.id === tid);
                const correct = theorist?.concepts.includes(cid);
                return (
                  <div key={cid} className={correct ? 'opacity-90' : 'opacity-60'}>
                    {correct ? '✓' : '✗'} {concept?.label} → {theorist?.name}
                  </div>
                );
              })}
            </div>
            <button onClick={done} className="w-full py-2 border border-current text-sm tracking-[0.2em] hover:bg-current hover:text-black transition-colors">
              CONTINUE
            </button>
          </>
        )}
      </div>
    </div>
  );
}
