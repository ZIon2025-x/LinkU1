import React, { useState, useEffect, useRef, useMemo, useCallback } from 'react';
import { audio } from '../engine/audio.js';
import {
  YELLOW_LABEL_ITEMS, PRET_QUESTIONS, ESSAY_PUZZLES, THEORIST_MATCH,
  PRET_SETS, pickPretSet, pretMaskRate,
  WORD_SET, LECTURE_THEMES, pickLectureTheme, lectureTimeForWeek,
  scoreWord, lectureAcademic, generateLectureGrid,
  lectureDirInfo, isLectureAdjacent,
  DESIGN_BRIEFS, DESIGN_PALETTES, pickDesignBrief, scoreDesignBrief,
  pickEssayPuzzles, pickMatchRound,
  generateYellowLabelRound, yellowLabelConfig,
} from '../data/index.js';

// 按 mask rate 决定一个词是否被打码。短词(≤2 chars)永不打。
function maskKeyWord(text, rate) {
  if (!text || rate <= 0) return null;
  if (Math.random() * 100 > rate) return null;
  return text;  // mark for masking
}

// 把 staff 文本里的 maskable 关键词部分打成 ████。同一句里逐个 maskable 独立判断。
function renderMaskedText(text, maskable, maskRate) {
  if (!maskable || maskable.length === 0 || maskRate <= 0) return text;
  let result = text;
  maskable.forEach(phrase => {
    if (Math.random() * 100 > maskRate) return;
    // 替换第一处出现的 phrase 为 same-length 的 █ 块(保留首末 1 char 给一点 hint,真有听力 ≥ 50% 时)
    const idx = result.indexOf(phrase);
    if (idx < 0) return;
    const masked = '█'.repeat(Math.max(2, phrase.length - 1));
    result = result.slice(0, idx) + masked + result.slice(idx + phrase.length);
  });
  return result;
}

export function YellowLabelMinigame({ onComplete, feedback, onDismiss, week }) {
  // 生成本场 round + 难度配置
  const round = useMemo(() => generateYellowLabelRound(week || 1), [week]);
  const items = round.items;
  const cfg = round.cfg;
  const cols = cfg.cards <= 4 ? 2 : cfg.cards === 6 ? 3 : 4;

  // 位置数组 positions[slot] = item idx — 洗牌通过 swap positions 实现
  const initialPositions = useMemo(() => items.map((_, i) => i), [items]);
  const [positions, setPositions] = useState(initialPositions);
  // phase: ready | peek | flipping | shuffling | pick | done
  const [phase, setPhase] = useState('ready');
  const [picked, setPicked] = useState(new Set());
  const [shuffleCount, setShuffleCount] = useState(0);
  const timerRef = useRef(null);
  const shuffleRef = useRef(null);

  function start() {
    audio.click();
    setPhase('peek');
    // 显示 N 毫秒后翻面
    timerRef.current = setTimeout(() => {
      audio.message();
      setPhase('flipping');
      // 翻面动画 500ms 后开始洗牌
      setTimeout(() => {
        setPhase('shuffling');
        runShuffle(0);
      }, 500);
    }, cfg.peekMs);
  }

  function runShuffle(count) {
    if (count >= cfg.shuffles) {
      setPhase('pick');
      return;
    }
    // 随机 swap 两个 position
    setPositions(prev => {
      const next = [...prev];
      const a = Math.floor(Math.random() * next.length);
      let b = Math.floor(Math.random() * next.length);
      while (b === a) b = Math.floor(Math.random() * next.length);
      [next[a], next[b]] = [next[b], next[a]];
      return next;
    });
    setShuffleCount(count + 1);
    shuffleRef.current = setTimeout(() => runShuffle(count + 1), cfg.shuffleMs);
  }

  function tapItem(itemIdx) {
    if (phase !== 'pick') return;
    audio.click();
    const next = new Set(picked);
    if (next.has(itemIdx)) next.delete(itemIdx);
    else next.add(itemIdx);
    setPicked(next);
  }

  function submit() {
    audio.click();
    setPhase('done');
    // 评分
    const correct = [...picked].filter(idx => items[idx].isYellow);
    const wrong = [...picked].filter(idx => !items[idx].isYellow);
    const missed = items.filter((it, i) => it.isYellow && !picked.has(i));
    const totalCost = correct.reduce((s, idx) => s + items[idx].price, 0)
                    + wrong.reduce((s, idx) => s + items[idx].price * 1.5, 0);  // 错抢扣 1.5x 价
    const success = correct.length === cfg.yellowCount && wrong.length === 0;
    const result = {
      success,
      correct: correct.length,
      total: cfg.yellowCount,
      wrong: wrong.length,
      effect: {
        wallet: -Math.round(totalCost),
        energy: success ? 4 : -3,
        belonging: success ? 3 : 0,
      },
      feedback: success
        ? `🎯 全中 ${correct.length}/${cfg.yellowCount} 黄标 · 0 误判。Tesco 出口你跟另一个亚洲面孔擦肩,他点了点头——某种隐秘的同盟。`
        : correct.length > 0 && wrong.length === 0
        ? `抓住 ${correct.length}/${cfg.yellowCount},错过 ${missed.length} 个。下次记快点。`
        : wrong.length > 0
        ? `${correct.length}/${cfg.yellowCount} 黄标,但错抢 ${wrong.length} 件原价 (扣 1.5×)。小票看了你一眼。`
        : `一个没抓住。回家煮泡面。`,
    };
    onComplete(result);
  }

  useEffect(() => () => {
    clearTimeout(timerRef.current);
    clearTimeout(shuffleRef.current);
  }, []);

  // ✨ 几何:固定 grid 320px 宽,gap 8px,cellSize 按 cols 算
  // 每个 item 一个 stable key(item.id),用 transform 决定位置 → 位置变化触发 CSS transition
  const GRID_W = 320;
  const GAP = 8;
  const rows = Math.ceil(cfg.cards / cols);
  const cellSize = (GRID_W - (cols - 1) * GAP) / cols;
  const gridH = rows * cellSize + (rows - 1) * GAP;
  const itemSlot = useMemo(() => {
    const m = {};
    positions.forEach((itemIdx, slot) => { m[itemIdx] = slot; });
    return m;
  }, [positions]);

  function renderCard(item, itemIdx) {
    const slot = itemSlot[itemIdx];
    const r = Math.floor(slot / cols);
    const c = slot % cols;
    const x = c * (cellSize + GAP);
    const y = r * (cellSize + GAP);
    const faceUp = phase === 'ready' || phase === 'peek' || phase === 'done';
    const isPicked = picked.has(itemIdx);
    const showLabel = (phase === 'peek' || phase === 'ready' || phase === 'done') && item.isYellow;
    let bg, borderColor, shadow;
    if (phase === 'done' && item.isYellow && isPicked) { bg = 'rgba(160,200,144,0.2)'; borderColor = '#a0c890'; shadow = 'none'; }
    else if (phase === 'done' && !item.isYellow && isPicked) { bg = 'rgba(200,96,96,0.2)'; borderColor = '#c86060'; shadow = 'none'; }
    else if (isPicked) { bg = 'rgba(212,176,112,0.18)'; borderColor = '#d4b070'; shadow = '0 0 0 2px rgba(212,176,112,0.4)'; }
    else if (!faceUp) { bg = 'rgba(90,138,168,0.1)'; borderColor = 'rgba(232,224,208,0.4)'; shadow = 'none'; }
    else { bg = 'transparent'; borderColor = 'rgba(232,224,208,0.4)'; shadow = 'none'; }
    return (
      <button
        key={item.id}    // ✨ stable key = item.id,不再是 slot
        onClick={() => tapItem(itemIdx)}
        disabled={phase !== 'pick'}
        className="border flex flex-col items-center justify-center"
        style={{
          position: 'absolute',
          left: 0, top: 0,
          width: cellSize, height: cellSize,
          transform: `translate(${x}px, ${y}px)`,
          transition: `transform ${cfg.shuffleMs}ms cubic-bezier(.7,.1,.2,1), background 200ms, border-color 200ms, box-shadow 200ms`,
          willChange: 'transform',
          borderColor, background: bg, boxShadow: shadow,
          cursor: phase === 'pick' ? 'pointer' : 'default',
          color: 'inherit',
        }}>
        {showLabel && (
          <div className="absolute top-1 right-1 px-1 text-[8px]"
               style={{ background: '#d4b070', color: '#1a1612', fontFamily: 'monospace' }}>
            £{item.price}
          </div>
        )}
        {faceUp ? (
          <>
            <div className="text-3xl">{item.emoji}</div>
            <div className="text-xs mt-1 opacity-70">{item.name}</div>
            {phase === 'done' && item.isYellow && !isPicked && (
              <div className="absolute inset-0 flex items-center justify-center text-2xl" style={{ color: '#d4b070', background: 'rgba(212,176,112,0.18)' }}>?</div>
            )}
            {phase === 'done' && item.isYellow && isPicked && (
              <div className="absolute top-1 left-1 text-sm" style={{ color: '#a0c890' }}>✓</div>
            )}
            {phase === 'done' && !item.isYellow && isPicked && (
              <div className="absolute bottom-1 right-1 text-sm" style={{ color: '#c86060' }}>✗</div>
            )}
          </>
        ) : (
          <div className="text-3xl opacity-70" style={{ color: '#5a8aa8' }}>?</div>
        )}
      </button>
    );
  }

  return (
    <div className="fixed inset-0 z-40 flex items-center justify-center p-4" style={{ background: 'rgba(10, 8, 6, 0.9)' }}>
      <div className="bg-[#1a1612] border border-current/40 max-w-md w-full p-5 animate-fadein">
        <div className="text-xs tracking-[0.3em] opacity-50 mb-2" style={{ fontFamily: 'monospace' }}>MINIGAME · LV {cfg.cards}x{cfg.yellowCount}</div>
        <h2 className="text-xl mb-3 font-light">🛒 抢黄标 · 记忆挑战</h2>

        {phase === 'ready' && (
          <>
            <div className="text-sm opacity-90 mb-4" style={{ lineHeight: '1.8' }}>
              晚上 9 点 Tesco。员工把一批 <span style={{ color: '#d4b070' }}>£X 黄标</span> 商品摆出来。<br/>
              <br/>
              · 看 {cfg.peekMs/1000}s 记住哪几张是黄标<br/>
              · 卡牌翻面 + 洗 {cfg.shuffles} 次<br/>
              · 点出 <strong style={{ color: '#d4b070' }}>{cfg.yellowCount}</strong> 张黄标的位置<br/>
              · 错抢扣 1.5× 价
            </div>
            <button onClick={start} className="w-full py-3 border border-current hover:bg-current hover:text-black transition-colors tracking-[0.2em] text-sm">
              开始
            </button>
            <button onClick={onDismiss} className="w-full mt-2 p-2 text-xs opacity-60 hover:opacity-100">不抢 →</button>
          </>
        )}

        {(phase === 'peek' || phase === 'flipping' || phase === 'shuffling' || phase === 'pick' || phase === 'done') && (
          <>
            <div className="flex justify-between mb-3 items-center text-xs" style={{ fontFamily: 'monospace' }}>
              <div className="opacity-70">
                {phase === 'peek' && `👀 记住 · ${cfg.yellowCount} 张黄标`}
                {phase === 'flipping' && '🔄 翻面...'}
                {phase === 'shuffling' && `🌀 洗牌 ${shuffleCount}/${cfg.shuffles}`}
                {phase === 'pick' && `选 ${cfg.yellowCount} 张 · 已选 ${picked.size}`}
                {phase === 'done' && '结果'}
              </div>
              {phase === 'pick' && (
                <button onClick={submit} disabled={picked.size === 0}
                  className="px-3 py-1 border disabled:opacity-30"
                  style={{ borderColor: '#a0c890', color: '#a0c890' }}>
                  确认
                </button>
              )}
            </div>
            <div style={{ position: 'relative', width: GRID_W, height: gridH, margin: '0 auto' }}>
              {items.map((item, i) => renderCard(item, i))}
            </div>
            {phase === 'done' && (
              <button onClick={onDismiss} className="w-full mt-3 py-2 border border-current text-sm tracking-[0.2em] hover:bg-current hover:text-black transition-colors">
                CONTINUE
              </button>
            )}
          </>
        )}

        {feedback && phase === 'done' && (
          <div className="mt-3 border-l-2 border-current/50 pl-4 py-1 italic opacity-90 text-sm" style={{ lineHeight: '1.8' }}>{feedback}</div>
        )}
      </div>
    </div>
  );
}
export function PretMinigame({ onComplete, onCancel, week, pretPlaysCount }) {
  // 按玩家进度选一套对话(避免重复) + 锁定本场 maskRate
  const set = useMemo(() => pickPretSet(pretPlaysCount || 0), [pretPlaysCount]);
  const maskRate = useMemo(() => pretMaskRate(week || 1, pretPlaysCount || 0), [week, pretPlaysCount]);
  // 每句的 mask 结果在挂载时锁定,避免每次 re-render 重新随机
  const maskedStaff = useMemo(
    () => set.questions.map(q => renderMaskedText(q.staff, q.maskable, maskRate)),
    [set, maskRate],
  );

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
    if (currentQ + 1 < set.questions.length) {
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
      total: set.questions.length,
      incrementPretPlays: true,
      effect: {
        wallet: -5,
        energy: correctCount >= 4 ? 5 : -3,
        belonging: correctCount >= 4 ? 6 : correctCount >= 3 ? 2 : -3,
      },
      feedback: correctCount >= 4
        ? `你点完单走出去，回头店员还在跟你笑。${correctCount}/5——这场对话顺得多了。`
        : correctCount >= 3
        ? `你拿到了咖啡。比平时凉一点,你猜是因为你站在那里太久。${correctCount}/5。`
        : `你拿到了东西，但你在路上走了 5 分钟才想起这次的对话每一句都说得磕磕绊绊。${correctCount}/5。明天还得继续。`,
    };
    onComplete(result);
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 animate-fadein" style={{ background: 'rgba(10, 8, 6, 0.95)' }}>
      <div className="bg-[#1a1612] border border-current/40 max-w-md w-full p-5">
        <div className="text-xs tracking-[0.3em] opacity-50 mb-2" style={{ fontFamily: 'monospace' }}>☕ MINIGAME · LISTENING {100 - maskRate}%</div>
        <h2 className="text-xl mb-1 font-light">{set.setting}</h2>
        <div className="text-xs opacity-60 italic mb-4" style={{ fontFamily: 'monospace' }}>5 句对话 · 你能听懂多少？</div>

        {/* 听力条 */}
        <div className="flex items-center gap-2 mb-4 text-[10px] opacity-70" style={{ fontFamily: 'monospace' }}>
          <span>听力</span>
          <div className="flex-1 h-1 bg-current/15 relative">
            <div className="absolute left-0 top-0 bottom-0"
                 style={{ width: `${100 - maskRate}%`, background: maskRate <= 10 ? '#a0c890' : '#d4b070' }} />
          </div>
          <span>{100 - maskRate}%</span>
        </div>

        {phase === 'intro' && (
          <>
            <div className="text-sm opacity-90 mb-5 whitespace-pre-line" style={{ lineHeight: '1.85' }}>
              {set.intro}
            </div>
            <button onClick={start} className="w-full py-3 border border-current hover:bg-current hover:text-black transition-colors tracking-[0.2em] text-sm">
              点单
            </button>
            <button onClick={onCancel} className="w-full mt-2 p-2 text-xs opacity-60 hover:opacity-100">逃出去 →</button>
          </>
        )}

        {phase === 'quiz' && !showFeedback && (
          <>
            <div className="text-xs opacity-60 mb-2" style={{ fontFamily: 'monospace' }}>第 {currentQ + 1} 句 / 共 {set.questions.length} 句</div>
            <div className="border-l-2 border-current/50 pl-4 py-2 mb-4 italic text-base" style={{ lineHeight: '1.6' }}>
              <span className="opacity-60 text-xs not-italic mr-2">店员：</span>
              <span style={{ fontFamily: maskRate > 0 ? 'monospace' : 'inherit', letterSpacing: maskRate > 0 ? '0.02em' : 'normal' }}>
                {maskedStaff[currentQ]}
              </span>
            </div>
            <div className="space-y-2">
              {set.questions[currentQ].options.map((opt, i) => (
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
              {currentQ + 1 < set.questions.length ? 'NEXT' : '看结果'}
            </button>
          </>
        )}

        {phase === 'done' && (
          <>
            <div className="text-center my-6">
              <div className="text-xs opacity-60 mb-1" style={{ fontFamily: 'monospace' }}>YOUR SCORE</div>
              <div className="text-5xl font-light" style={{ fontFamily: 'monospace',
                color: answers.filter(a => a.correct).length >= 4 ? '#a0c890' : '#d4b070' }}>
                {answers.filter(a => a.correct).length}/{set.questions.length}
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

export function EssayMinigame({ onComplete, onCancel, week }) {
  // 按 week 抽 3 个 puzzle(phase 1/2/3 池),锁定挂载时
  const puzzles = useMemo(() => pickEssayPuzzles(week || 1, []), [week]);
  const [puzzleIdx, setPuzzleIdx] = useState(0);
  const [pickedIdx, setPickedIdx] = useState(null);
  const [score, setScore] = useState(0);
  const [showFb, setShowFb] = useState(null);

  const puzzle = puzzles[puzzleIdx];

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
    if (puzzleIdx + 1 < puzzles.length) {
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
      total: puzzles.length,
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
        <div className="text-xs opacity-60 italic mb-4" style={{ fontFamily: 'monospace' }}>填入最合适的句子 · {puzzleIdx + 1}/{puzzles.length}</div>

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
              {puzzleIdx + 1 < puzzles.length ? 'NEXT' : '完成'}
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

export function MatchMinigame({ onComplete, onCancel, week }) {
  // 按 week 抽:phase 1 = 4 theorists + 6 concepts, phase 2 = 6+9, phase 3 = 8+12
  const [roundData] = useState(() => pickMatchRound(week || 1));
  const round = useMemo(
    () => roundData.concepts.map(cid => ({ id: cid, ...THEORIST_MATCH.concepts[cid] })),
    [roundData],
  );
  const visibleTheorists = roundData.theorists;
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
      const theorist = visibleTheorists.find(t => t.id === tid);
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
                {visibleTheorists.map(t => {
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
                const theorist = visibleTheorists.find(t => t.id === tid);
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

// ========================================
// 上课字母连词 minigame
// ========================================
export function LectureMinigame({ onComplete, onCancel, week }) {
  const theme = useMemo(() => pickLectureTheme(week || 1), [week]);
  const totalTime = useMemo(() => lectureTimeForWeek(week || 1), [week]);
  const dirInfo = useMemo(() => lectureDirInfo(week || 1), [week]);

  const [phase, setPhase] = useState('intro');
  const [grid] = useState(() => generateLectureGrid(theme));
  const [path, setPath] = useState([]);
  const [foundWords, setFoundWords] = useState([]);
  const [usedCells, setUsedCells] = useState(() => new Set());
  const [score, setScore] = useState(0);
  const [timeLeft, setTimeLeft] = useState(totalTime);
  const [lastWordFeedback, setLastWordFeedback] = useState(null);
  const timerRef = useRef(null);

  function start() {
    audio.click();
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

  const cellKey = (r, c) => `${r}:${c}`;
  const isAdjacent = useCallback((a, b) => isLectureAdjacent(a, b, dirInfo.dirs), [dirInfo]);

  function tapCell(r, c) {
    if (phase !== 'playing') return;
    audio.click();
    const last = path[path.length - 1];
    const prev = path[path.length - 2];
    if (prev && prev.r === r && prev.c === c) {
      setPath(path.slice(0, -1));
      return;
    }
    if (path.some(p => p.r === r && p.c === c)) return;
    if (path.length === 0) {
      setPath([...path, { r, c }]);
      return;
    }
    if (isAdjacent(last, { r, c })) {
      setPath([...path, { r, c }]);
      return;
    }
    // 不相邻或方向受 tier 限制 — 给反馈
    const dr = Math.abs(last.r - r);
    const dc = Math.abs(last.c - c);
    if (dr <= 1 && dc <= 1 && !(dr === 0 && dc === 0)) {
      let dirName = '';
      if (dr === 1 && dc === 0) dirName = '竖';
      else if (dr === 1 && dc === 1) dirName = '斜';
      if (dirName) {
        audio.fail();
        setLastWordFeedback({
          word: '',
          message: `W${week} 还不能${dirName}着连 (本周:${dirInfo.label})`,
          bad: true,
        });
      }
    }
  }

  function clearPath() {
    audio.click();
    setPath([]);
  }

  function submitWord() {
    if (path.length < 3) {
      audio.fail();
      setLastWordFeedback({ word: '', message: '太短了 (至少 3 字母)', bad: true });
      setPath([]);
      return;
    }
    const word = path.map(p => grid[p.r][p.c]).join('').toUpperCase();
    if (foundWords.some(f => f.word === word)) {
      audio.fail();
      setLastWordFeedback({ word, message: '已经连过了', bad: true });
      setPath([]);
      return;
    }
    if (!WORD_SET.has(word)) {
      audio.fail();
      setLastWordFeedback({ word, message: '不是英文单词', bad: true });
      setPath([]);
      return;
    }
    const { points, isBonus } = scoreWord(word, theme);
    audio.success();
    setFoundWords([...foundWords, { word, points, bonus: isBonus }]);
    setScore(score + points);
    const next = new Set(usedCells);
    path.forEach(p => next.add(cellKey(p.r, p.c)));
    setUsedCells(next);
    setLastWordFeedback({ word, message: isBonus ? `+${points} ★ 当周关键词!` : `+${points}`, bad: false });
    setPath([]);
  }

  function finish() {
    if (phase === 'playing') {
      clearInterval(timerRef.current);
      setPhase('done');
    }
    const academicGain = lectureAcademic(score);
    onComplete({
      score, total: foundWords.length,
      effect: {
        academic: academicGain,
        energy: -6,
        belonging: foundWords.some(f => f.bonus) ? 2 : 0,
      },
      attendedClass: true,
      feedback: score >= 25
        ? `你连出 ${foundWords.length} 个词，${score} 分——Whitmore 讲的你居然抓到了 ${foundWords.filter(f => f.bonus).length} 个关键词。lecture 没白上。`
        : score >= 8
        ? `你连出 ${foundWords.length} 个词，${score} 分。lecture 听了一半，笔记本写了一半。还行。`
        : `你连出 ${foundWords.length} 个词，${score} 分。你大部分时间在盯天花板。下次集中点。`,
    });
  }

  useEffect(() => () => clearInterval(timerRef.current), []);

  const currentWord = path.map(p => grid[p.r][p.c]).join('');

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-3 animate-fadein" style={{ background: 'rgba(10, 8, 6, 0.95)' }}>
      <div className="bg-[#1a1612] border border-current/40 max-w-md w-full p-4 max-h-[95vh] overflow-y-auto">
        <div className="text-xs tracking-[0.3em] mb-1" style={{ fontFamily: 'monospace', color: '#d4b070' }}>📖 MINIGAME · LECTURE</div>
        <h2 className="text-lg mb-1 font-light">{theme.name}</h2>
        <div className="text-xs opacity-60 italic mb-3" style={{ fontFamily: 'monospace' }}>字母连词 · {totalTime} 秒 · 抓当周关键词 ★</div>

        {phase === 'intro' && (
          <>
            <div className="text-sm opacity-90 mb-4" style={{ lineHeight: '1.85' }}>
              Whitmore 在黑板上写理论。你的笔记本上是一团字母。<br/>
              <br/>
              <span style={{ color: '#d4b070' }}>· 本周可连：<strong>{dirInfo.label}</strong>（{dirInfo.desc}）</span><br/>
              · 点击相邻字母连成英文单词<br/>
              · 3+ 字母才算分，越长分越高<br/>
              · 撞当周主题词 ★ 分数翻倍<br/>
              · 时间到自动交卷<br/>
              <br/>
              <span className="opacity-60">本场:{totalTime} 秒 · 主题 {theme.bonus.slice(0, 4).join(' / ')} ...</span>
            </div>
            <button onClick={start} className="w-full py-3 border border-current hover:bg-current hover:text-black transition-colors tracking-[0.2em] text-sm">
              开始
            </button>
            <button onClick={onCancel} className="w-full mt-2 p-2 text-xs opacity-60 hover:opacity-100">放弃这节课 →</button>
          </>
        )}

        {phase === 'playing' && (
          <>
            <div className="flex justify-between items-center mb-2 text-xs" style={{ fontFamily: 'monospace' }}>
              <div><span className="opacity-60">分数 </span><span style={{ color: '#a0c890' }}>{score}</span></div>
              <div><span className="opacity-60">已连 </span>{foundWords.length}</div>
              <div><span className="opacity-60">时间 </span><span style={{ color: timeLeft <= 15 ? '#c86060' : '#e8e0d0', fontSize: '14px' }}>{timeLeft}s</span></div>
            </div>

            <div className="border border-dashed border-current/40 rounded px-2 py-1 mb-2 text-center min-h-[28px]"
                 style={{ fontFamily: 'monospace', fontSize: '14px', letterSpacing: '0.1em', color: '#d4b070' }}>
              {currentWord || <span className="opacity-30 italic" style={{ fontSize: '10px' }}>点字母开始</span>}
            </div>

            <div className="grid grid-cols-10 gap-[2px] mb-2">
              {grid.map((row, r) =>
                row.map((ch, c) => {
                  const k = cellKey(r, c);
                  const inPath = path.some(p => p.r === r && p.c === c);
                  const used = usedCells.has(k);
                  return (
                    <button key={k} onClick={() => tapCell(r, c)}
                      className="aspect-square flex items-center justify-center font-bold transition-colors"
                      style={{
                        fontFamily: 'monospace',
                        fontSize: '11px',
                        border: '1px solid rgba(212,176,112,0.35)',
                        background: inPath ? 'rgba(212,176,112,0.45)' : used ? 'rgba(160,200,144,0.08)' : 'rgba(212,176,112,0.04)',
                        color: inPath ? '#fff' : used ? 'rgba(232,224,208,0.45)' : '#d4b070',
                        boxShadow: inPath ? '0 0 0 1px #d4b070' : 'none',
                      }}>
                      {ch}
                    </button>
                  );
                })
              )}
            </div>

            <div className="flex gap-2 mb-2">
              <button onClick={clearPath} disabled={path.length === 0}
                className="flex-1 py-1.5 border border-current/40 text-xs hover:bg-current/5 disabled:opacity-30">清空</button>
              <button onClick={submitWord} disabled={path.length < 3}
                className="flex-1 py-1.5 border text-xs disabled:opacity-30"
                style={{ borderColor: path.length >= 3 ? '#a0c890' : 'rgba(232,224,208,0.4)', color: path.length >= 3 ? '#a0c890' : 'inherit' }}>
                连!
              </button>
            </div>

            {lastWordFeedback && (
              <div className={`text-xs italic mb-2 px-2 py-1 ${lastWordFeedback.bad ? 'opacity-70' : ''}`}
                   style={{ color: lastWordFeedback.bad ? '#c86060' : '#a0c890', fontFamily: 'monospace' }}>
                {lastWordFeedback.word ? `${lastWordFeedback.word} — ` : ''}{lastWordFeedback.message}
              </div>
            )}

            {foundWords.length > 0 && (
              <div className="flex flex-wrap gap-1 mt-2 max-h-16 overflow-y-auto">
                {foundWords.map((f, i) => (
                  <span key={i} className="px-1.5 py-0.5 border text-[10px]"
                        style={{
                          fontFamily: 'monospace',
                          borderColor: f.bonus ? '#d4b070' : 'rgba(160,200,144,0.4)',
                          color: f.bonus ? '#d4b070' : '#a0c890',
                          background: f.bonus ? 'rgba(212,176,112,0.1)' : 'rgba(160,200,144,0.05)',
                        }}>
                    {f.word}<span className="opacity-60 ml-1">+{f.points}{f.bonus ? '★' : ''}</span>
                  </span>
                ))}
              </div>
            )}

            <button onClick={finish} className="w-full mt-2 py-1.5 text-xs opacity-60 hover:opacity-100">交卷 →</button>
          </>
        )}

        {phase === 'done' && (
          <>
            <div className="text-center my-4">
              <div className="text-xs opacity-60 mb-1" style={{ fontFamily: 'monospace' }}>FINAL SCORE</div>
              <div className="text-5xl font-light mb-2" style={{
                fontFamily: 'monospace',
                color: score >= 25 ? '#a0c890' : score >= 8 ? '#d4b070' : '#c86060',
              }}>{score}</div>
              <div className="text-xs opacity-60">{foundWords.length} 词 · {foundWords.filter(f => f.bonus).length} ★ 关键词</div>
            </div>
            <button onClick={finish} className="w-full py-2 border border-current text-sm tracking-[0.2em] hover:bg-current hover:text-black transition-colors">
              CONTINUE
            </button>
          </>
        )}
      </div>
    </div>
  );
}

// ========================================
// AI 设计 · 客户简介解码 minigame (4 步)
// ========================================
export function DesignBriefMinigame({ onComplete, onCancel, week, seenBriefIds = [] }) {
  const brief = useMemo(() => pickDesignBrief(week || 1, seenBriefIds), [week, seenBriefIds]);
  const phase = brief.phase;
  // 每步 shuffle options (锁定一次)
  const shuffledSteps = useMemo(() => brief.steps.map(s => {
    const opts = [...s.options].map((o, i) => ({ ...o, _origIdx: i }));
    // Fisher-Yates
    for (let i = opts.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [opts[i], opts[j]] = [opts[j], opts[i]];
    }
    return { ...s, options: opts };
  }), [brief]);

  const [stage, setStage] = useState('intro'); // intro | step | done
  const [stepIdx, setStepIdx] = useState(0);
  const [answers, setAnswers] = useState([]); // boolean[]
  const [pickedIdx, setPickedIdx] = useState(null);
  const [showWhy, setShowWhy] = useState(null);

  function start() { audio.click(); setStage('step'); }

  function pickOption(idx) {
    audio.click();
    const opt = shuffledSteps[stepIdx].options[idx];
    setPickedIdx(idx);
    if (opt.correct) audio.success(); else audio.fail();
    setShowWhy(opt);
    setAnswers([...answers, !!opt.correct]);
  }

  function nextStep() {
    audio.click();
    setShowWhy(null);
    setPickedIdx(null);
    if (stepIdx + 1 < shuffledSteps.length) {
      setStepIdx(stepIdx + 1);
    } else {
      setStage('done');
    }
  }

  function finish() {
    audio.click();
    const correctCount = answers.filter(Boolean).length;
    const tier = scoreDesignBrief(correctCount, phase);
    const finalReward = Math.round(brief.reward * tier.mult);
    onComplete({
      briefId: brief.id,
      correctCount,
      total: 4,
      stars: tier.stars,
      reward: finalReward,
      baseReward: brief.reward,
      effect: {
        wallet: finalReward,
        energy: -8,
        academic: correctCount >= 3 ? 2 : 0,
        belonging: tier.stars >= 4 ? 3 : 0,
      },
      feedback: tier.stars === 5
        ? `${brief.client.name} 看完成品:"WOW 这就是我要的!! ⭐⭐⭐⭐⭐"\n\n+£${finalReward} (奖励 25%)。她下次还会找你 + 朋友圈推荐。`
        : tier.stars === 4
        ? `${brief.client.name}:"还不错,有些细节不太对但能用。⭐⭐⭐⭐"\n\n+£${finalReward}。`
        : tier.stars === 3
        ? `${brief.client.name}:"嗯...可以但不是我想要的感觉。⭐⭐⭐"\n\n+£${finalReward}。她下次可能不找你了。`
        : tier.stars === 2
        ? `${brief.client.name}:"这不是我说的那种 vibe。⭐⭐"\n\n+£${finalReward} (扣了)。差评进 profile。`
        : `${brief.client.name}:"我...再考虑一下。" ⭐\n\n+£${finalReward}。她最后跟朋友说你"不懂"。`,
    });
  }

  const current = shuffledSteps[stepIdx];
  const correctSoFar = answers.filter(Boolean).length;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-3 animate-fadein" style={{ background: 'rgba(10, 8, 6, 0.95)' }}>
      <div className="bg-[#1a1612] border max-w-md w-full p-4 max-h-[95vh] overflow-y-auto"
           style={{ borderColor: 'rgba(122,138,106,0.4)' }}>
        <div className="text-xs tracking-[0.3em] mb-1" style={{ fontFamily: 'monospace', color: '#7a8a6a' }}>🎨 MINIGAME · BRIEF · Phase {phase}</div>
        <h2 className="text-lg mb-1 font-light">{brief.subject}</h2>
        <div className="text-xs opacity-60 italic mb-3" style={{ fontFamily: 'monospace' }}>解码客户 · 4 步</div>

        {/* 客户 brief card */}
        <div className="border rounded p-3 mb-3 text-sm leading-relaxed"
             style={{ borderColor: 'rgba(122,138,106,0.4)', background: 'rgba(122,138,106,0.05)' }}>
          <div className="flex items-center gap-2 mb-2 text-xs opacity-70" style={{ fontFamily: 'monospace' }}>
            <div className="w-6 h-6 rounded-full flex items-center justify-center text-xs"
                 style={{ background: '#b85070', color: 'white' }}>{brief.client.emoji}</div>
            <span>{brief.client.name} · {brief.client.desc} · £{brief.reward}</span>
          </div>
          <div className="italic opacity-85">{brief.brief}</div>
        </div>

        {/* Step progress dots */}
        {stage !== 'intro' && (
          <div className="flex gap-1.5 mb-3 justify-center">
            {[0,1,2,3].map(i => (
              <div key={i} className="h-1 flex-1 max-w-[40px]" style={{
                background: i < stepIdx ? (answers[i] ? '#a0c890' : '#c86060')
                  : i === stepIdx && stage === 'step' ? '#7a8a6a' : 'rgba(232,224,208,0.15)',
              }} />
            ))}
          </div>
        )}

        {stage === 'intro' && (
          <>
            <div className="text-sm opacity-90 mb-4" style={{ lineHeight: '1.85' }}>
              客户给的 brief 通常含糊。你的工作是把废话翻译成 4 个明确的设计决定。<br/>
              <br/>
              · 4 步:解读意图 / mood / 配色 / 格式<br/>
              · 每步 4 选项,1 正确 + 3 典型失败<br/>
              · 满分 4/4 = 5⭐ + 25% 奖励金<br/>
              · Phase {phase} = {phase === 1 ? '入门级' : phase === 2 ? '客户有矛盾要求' : '挑剔客户,wrong option 也 plausible'}
            </div>
            <button onClick={start} className="w-full py-3 border hover:bg-current hover:text-black transition-colors tracking-[0.2em] text-sm"
                    style={{ borderColor: '#7a8a6a', color: '#7a8a6a' }}>
              开始接单
            </button>
            <button onClick={onCancel} className="w-full mt-2 p-2 text-xs opacity-60 hover:opacity-100">不接 →</button>
          </>
        )}

        {stage === 'step' && !showWhy && (
          <>
            <div className="text-xs mb-3 font-medium" style={{ color: '#7a8a6a', fontFamily: 'monospace' }}>
              第 {stepIdx + 1}/4 步 · {current.q}
            </div>
            <div className="space-y-2">
              {current.options.map((opt, i) => {
                const paletteId = opt.paletteId;
                const palette = paletteId && DESIGN_PALETTES[paletteId];
                return (
                  <button key={i} onClick={() => pickOption(i)}
                    className="w-full text-left p-2.5 border border-current/40 hover:border-current hover:bg-current/5 transition-all">
                    <div className="text-sm">{opt.text}</div>
                    {palette && (
                      <>
                        <div className="flex gap-1 mt-1.5">
                          {palette.swatches.map((c, ci) => (
                            <div key={ci} className="w-5 h-5 border" style={{ background: c, borderColor: 'rgba(232,224,208,0.2)' }} />
                          ))}
                        </div>
                        <div className="text-[10px] opacity-50 italic mt-1">{palette.desc}</div>
                      </>
                    )}
                  </button>
                );
              })}
            </div>
          </>
        )}

        {showWhy && (
          <>
            <div className={`p-3 mb-3 border-l-2 italic text-sm`}
                 style={{
                   borderColor: showWhy.correct ? '#a0c890' : '#c86060',
                   color: showWhy.correct ? '#a0c890' : '#e8b0a0',
                   lineHeight: '1.7',
                 }}>
              {showWhy.correct ? '✓ ' : '✗ '}{showWhy.why || (showWhy.correct ? '正确' : '不是客户要的')}
            </div>
            <button onClick={nextStep} className="w-full py-2 border border-current text-sm tracking-[0.2em] hover:bg-current hover:text-black transition-colors">
              {stepIdx + 1 < 4 ? 'NEXT →' : '看评分'}
            </button>
          </>
        )}

        {stage === 'done' && (
          <>
            <div className="text-center my-4">
              <div className="text-xs opacity-60 mb-1" style={{ fontFamily: 'monospace' }}>CLIENT RATING</div>
              <div className="text-4xl font-light mb-2" style={{ color: '#d4b070' }}>
                {'⭐'.repeat(scoreDesignBrief(correctSoFar, phase).stars)}
              </div>
              <div className="text-xs opacity-60">{correctSoFar} / 4 答对</div>
            </div>
            <button onClick={finish} className="w-full py-2 border border-current text-sm tracking-[0.2em] hover:bg-current hover:text-black transition-colors">
              CONTINUE
            </button>
          </>
        )}
      </div>
    </div>
  );
}

