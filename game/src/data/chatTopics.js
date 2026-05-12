// 微信私聊 / 群聊的"底部回复选项" 数据。
//
// 每个交互 NPC 有一个 getOptions(ctx) 函数，按当前游戏 state（npcRel/flags/week
// + 最近 NPC 消息内容）动态返回 reply / question 选项列表。
//
// 一个 option 形状：
//   {
//     id: 'sarah_yes_senate',           // 唯一 id 用于去重
//     group: 'sarah_senate_invite',     // 可选 · 互斥组 id —— 同 group 任一选完，整组消失
//     kind: 'reply' | 'ask',            // 决定按钮前缀（"回复 ·" or "问 ·"）
//     label: '"Sounds good"',           // 玩家点击的按钮文字
//     playerText: 'sounds good!',       // 玩家发送进对话的文字（可与 label 不同）
//     npcReply: '4pm 4 楼 我抢座 ☕',     // NPC 立即回应的文字（可省略）
//     effect: { npc: { sarah: 1 }, flag: 'studied_with_sarah_w6' },
//                     // 可选 · 永远不进 seen，可反复点
//   }
//
// option id 一旦使用过会进 seenChatOptions 不再重出（除非 repeatable: true）。
// group 一旦"消费"会进 seenChatOptions 带 '__g:' 前缀，整组互斥消失。

export const CHAT_NPC_META = {
  sarah:    { name: 'Sarah',     avatar: 'S', color: '#d4a574', tagline: '英国本地 · flatmate' },
  aditi:    { name: 'Aditi',     avatar: 'A', color: '#a87fb8', tagline: 'India · MSc 同 cohort' },
  wangkai:  { name: '王凯学长',   avatar: '凯', color: '#c4615a', tagline: 'PhD Y2 · 奶茶店' },
  mei:      { name: 'Mei 姐',    avatar: '梅', color: '#b85070', tagline: '中餐馆老板娘' },
  whitmore: { name: 'Prof. Whitmore', avatar: 'W', color: '#7a7060', tagline: 'supervisor' },
  linnan:   { name: '林可儿 / 林楠', avatar: '林', color: '#8e7ab8', tagline: '同班同学' },
  mark:     { name: 'Mark',      avatar: 'M', color: '#a07060', tagline: '隔壁房 flatmate' },
  tom:      { name: 'Tom',       avatar: 'T', color: '#7090a8', tagline: '另一间 flatmate · Manchester' },
  mom:      { name: '🇨🇳 妈妈',  avatar: '妈', color: '#cc4040', tagline: '北京 · 8 小时时差' },
  priya:    { name: 'Priya · Link2Ur', avatar: 'P', color: '#007AFF', tagline: 'Ops Lead · 一开始没人猜她是 founder' },
};

// helper: 检查 thread 最后一条 NPC 消息文字是否包含某关键词
const lastSaid = (thread, keyword) => {
  const themMsgs = (thread || []).filter(m => m.role === 'them');
  if (!themMsgs.length) return false;
  const last = themMsgs[themMsgs.length - 1];
  return (last.text || '').includes(keyword);
};

// helper: 该 option 是否还能选（id 没用过 + 互斥组没消费过）
const isFresh = (id, seen, group) => {
  const s = seen || [];
  if (s.includes(id)) return false;
  if (group && s.includes(`__g:${group}`)) return false;
  return true;
};

// helper: 是否满足 requires 链（必须所有 prerequisite 都已选过）
const meetsPrereq = (requires, seen) => {
  if (!requires || !requires.length) return true;
  return requires.every(r => (seen || []).includes(r));
};

// helper: 检查最后一条群成员消息是否包含 keyword + 没过期。
// 过期 = state.day 比那条消息晚 maxDaysOld 以上天（默认 4 天 = 半周）。
// 也 = 群里出来了新对话且新对话不再包含同 keyword，自然 fail。
const lastGroupSaid = (ctx, keyword, maxDaysOld = 4) => {
  const m = ctx?.lastGroupMemberMsg;
  if (!m) return false;
  if (!(m.text || '').includes(keyword)) return false;
  if (ctx.day && m.day != null && (ctx.day - m.day) > maxDaysOld) return false;
  return true;
};

// helper: 从 variants 数组里挑一条回复，按 day 做稳定旋转。
// variants 形如 [{ when: (ctx) => bool, replies: ['...', '...'] }]
// 第一个 when 通过的 group 命中，再从 replies 里按 day mod 选一句 —— 同一天问就是同一句，
// 跨天会换 —— 给 repeatable smalltalk 制造"每次都有点不一样"的真实感。
const pickReply = (ctx, variants) => {
  const day = ctx?.day || 1;
  for (const v of variants) {
    if (!v.when || v.when(ctx)) {
      const list = v.replies || [];
      if (!list.length) continue;
      return list[day % list.length];
    }
  }
  return '';
};

// 排序优先级 —— 5 slots 应该优先给最 contextual 的：
//   5 = 剧情触发（带 flag effect 或 storyline reveal）
//   4 = 状态关心（低 energy / 低 belonging / 钱紧）
//   3 = 上下文回复（接 NPC 最近一句话）
//   2 = 解锁的深度 ask（带 requires）
//   1 = 一般 ask
//   0 = repeatable smalltalk
const optionPriority = (opt) => {
  if (opt._priority !== undefined) return opt._priority;
  if (opt.effect && opt.effect.flag) return 5;
  if (opt.kind === 'reply') return 3;
  if (opt.requires && opt.requires.length) return 2;
  if (opt.kind === 'smalltalk') return 0;
  return 1;
};

// ─────────────────────────────────────────────────────────────
// Sarah · 友情线 (flatmate)
// ─────────────────────────────────────────────────────────────
function sarahOptions(ctx) {
  const { npcRel, flags, week, thread, seen, stats = {}, storyProgress = {}, weekPhase } = ctx;
  const rel = npcRel.sarah || 0;
  const sarahProgress = storyProgress.sarah || 0;
  const opts = [];

  // ─── 上下文回复 · 接 Sarah 最近发的话 ───
  // 同 group 互斥：邀约 Senate House，"去"和"改天"二选一
  if (lastSaid(thread, 'Senate House') && isFresh('sarah_senate', seen, 'sarah_senate_invite')) {
    opts.push({
      id: 'sarah_yes_senate', group: 'sarah_senate_invite', kind: 'reply',
      label: '"Sounds good, see you there"',
      playerText: 'Sounds good! See you 4pm.',
      npcReply: "cool. I'll grab the corner table on 4F ☕",
      effect: { npc: { sarah: 1 }, flag: 'studied_with_sarah' },
    });
    opts.push({
      id: 'sarah_essay_excuse', group: 'sarah_senate_invite', kind: 'reply',
      label: '"Got an essay 😭 next week?"',
      playerText: 'next week works better — got an essay due 😭',
      npcReply: 'no worries! pencil it in for next Tues',
      effect: {},
    });
  }
  if (lastSaid(thread, 'Welcome to UK') && isFresh('sarah_welcome_thanks', seen)) {
    opts.push({
      id: 'sarah_welcome_thanks', kind: 'reply',
      label: '"Thanks! Looking forward to it"',
      playerText: 'thanks Sarah! looking forward to class 🇬🇧',
      npcReply: '🙌 see you Monday!',
      effect: { npc: { sarah: 1 } },
    });
  }
  // ─── Proactive ping follow-ups ───
  // sarah_check_in_silence: "oi. you alive? 5 days no reply..."
  if (lastSaid(thread, 'you alive') && isFresh('sarah_alive_x', seen, 'sarah_alive_reply')) {
    opts.push({
      id: 'sarah_alive_honest', group: 'sarah_alive_reply', kind: 'reply',
      label: '"sorry — overwhelmed"',
      playerText: 'sorry mate. last week was a lot. coming up for air now.',
      npcReply: "ok come down then. wine, my room, 7. mandatory. you don't get out of this one.",
      effect: { npc: { sarah: 2 }, belonging: 6 },
    });
    opts.push({
      id: 'sarah_alive_brush', group: 'sarah_alive_reply', kind: 'reply',
      label: '"yeah just busy, all good"',
      playerText: "yeah just busy. all good.",
      npcReply: "mmm. we both know that's not it. but ok. ping me when ready.",
      effect: { npc: { sarah: -1 }, belonging: -2 },
    });
    opts.push({
      id: 'sarah_alive_meta', group: 'sarah_alive_reply', kind: 'reply',
      label: '"thanks for noticing actually"',
      playerText: "thanks for noticing actually. nobody else has.",
      npcReply: "babe. that's literally what flatmates are for. stop being british about it 😘",
      effect: { npc: { sarah: 3 }, belonging: 8 },
    });
  }
  // sarah_post_cotswolds_mum: "mum keeps asking when 'that lovely friend' is coming back"
  if (lastSaid(thread, 'mum keeps asking') && isFresh('sarah_mum_back_x', seen, 'sarah_mum_back')) {
    opts.push({
      id: 'sarah_mum_back_yes', group: 'sarah_mum_back', kind: 'reply',
      label: '"tell her March bank holiday weekend"',
      playerText: 'tell her — March bank holiday weekend? I want to come back.',
      npcReply: 'OH MY GOD. she\'s going to plan a 5-course menu by Tuesday. I\'ll warn dad.',
      effect: { npc: { sarah: 2 }, belonging: 8, flag: 'cotswolds_return_planned' },
    });
    opts.push({
      id: 'sarah_mum_back_dissertation', group: 'sarah_mum_back', kind: 'reply',
      label: '"after dissertation"',
      playerText: 'after dissertation 100% — June work?',
      npcReply: 'June works. mum will count down out loud probably.',
      effect: { npc: { sarah: 1 } },
    });
  }
  // sarah_post_scam_intuition: "babe you've been off..."
  if (lastSaid(thread, 'been off') && !flags.sarah_knows_scam &&
      isFresh('sarah_off_x', seen, 'sarah_off_reply')) {
    opts.push({
      id: 'sarah_off_open', group: 'sarah_off_reply', kind: 'reply',
      label: '"actually... can I come down?"',
      playerText: "actually — can I come down? something happened.",
      npcReply: "yes. door's open. kettle's on.",
      effect: { npc: { sarah: 4 }, flag: 'sarah_knows_scam', belonging: 12 },
    });
    opts.push({
      id: 'sarah_off_deflect', group: 'sarah_off_reply', kind: 'reply',
      label: '"all good — just dissertation"',
      playerText: "all good — just dissertation panic. thanks though.",
      npcReply: 'ok. but tea offer stands forever, just so you know.',
      effect: { npc: { sarah: 0 }, belonging: 1 },
    });
  }

  if (lastSaid(thread, 'James') && isFresh('sarah_james_advice', seen)) {
    opts.push({
      id: 'sarah_james_advice', kind: 'reply',
      label: '"Six hours is nothing — don\'t spiral"',
      playerText: "six hours is nothing — don't spiral",
      npcReply: 'cheers babe. voice of reason as always',
      effect: { npc: { sarah: 1 } },
    });
  }

  // ─── 主动问 · 按 rel 解锁 ───
  // ─── 深度链 1 · 家人话题（5 层）───
  // L1 → L5 解锁链，每层需要前一层选过
  if (rel >= 2 && isFresh('sarah_ask_weekend', seen)) {
    opts.push({
      id: 'sarah_ask_weekend', kind: 'ask',
      label: '"How was your weekend?"',
      playerText: 'how was your weekend?',
      npcReply: rel >= 6
        ? 'Cotswolds! mum made me weed the garden for 4 hours. living the dream 🥲'
        : 'pretty chill thanks. just laundry and a Tesco run',
      effect: { npc: { sarah: 1 } },
    });
  }
  if (rel >= 3 && isFresh('sarah_ask_cotswolds_more', seen)) {
    opts.push({
      id: 'sarah_ask_cotswolds_more', kind: 'ask',
      requires: ['sarah_ask_weekend'],
      label: '"What\'s Cotswolds actually like?"',
      playerText: 'what\'s Cotswolds actually like? I\'ve only seen it on TV',
      npcReply: 'sleepy, gorgeous, full of national trust members. dad\'s the local pub fixture. mum runs the church flower committee unironically. you\'d hate it for 2 days then love it.',
      effect: { npc: { sarah: 2 } },
    });
  }
  if (rel >= 4 && isFresh('sarah_ask_family_dynamic', seen)) {
    opts.push({
      id: 'sarah_ask_family_dynamic', kind: 'ask',
      requires: ['sarah_ask_cotswolds_more'],
      label: '"What\'s your family dynamic?"',
      playerText: 'family dynamic — you and mum vs dad? all chill? I\'m guessing mum\'s the loud one',
      npcReply: "yes 😂 mum's the engine. dad's the quiet one — but he watches everything. they've been married 32 years, they bicker like 18-year-olds.",
      effect: { npc: { sarah: 2 } },
    });
  }
  if (rel >= 5 && isFresh('sarah_ask_dad_real', seen)) {
    opts.push({
      id: 'sarah_ask_dad_real', kind: 'ask',
      requires: ['sarah_ask_family_dynamic'],
      label: '"How\'s your dad really doing?"',
      playerText: "real talk — how's your dad really? you said he's 'the quiet one' but I sense there's more",
      npcReply: "...thanks for asking. he's been struggling. won't admit it. mum's worried. I'm worried. we don't talk about it. you noticing means a lot.",
      effect: { npc: { sarah: 3 }, belonging: 6 },
    });
  }
  if (rel >= 7 && flags.cotswolds_visited && isFresh('sarah_invite_xmas_real', seen) && week >= 10) {
    opts.push({
      id: 'sarah_invite_xmas_real', kind: 'reply',
      requires: ['sarah_ask_dad_real'],
      label: '"I want to visit your dad — 圣诞 again?"',
      playerText: 'random — would it be weird if I came back to Cotswolds for Christmas? I want to see your dad before — you know',
      npcReply: 'oh god babe. yes. mum will lose her mind in the best way. dad will pretend it\'s nothing but he asked about you twice last month. come.',
      effect: { npc: { sarah: 4 }, belonging: 14, flag: 'sarah_xmas_invited' },
    });
  }
  if (rel >= 2 && isFresh('sarah_ask_reading', seen)) {
    opts.push({
      id: 'sarah_ask_reading', kind: 'ask',
      label: '"Did you finish this week\'s reading?"',
      playerText: 'did you actually finish all the reading this week or am I the only one drowning?',
      npcReply: "drowning. gave up Wednesday. let's just bluff in tutorial 😅",
      effect: { npc: { sarah: 1 } },
    });
  }
  if (rel >= 3 && isFresh('sarah_ask_pub', seen) && week >= 4) {
    opts.push({
      id: 'sarah_ask_pub', kind: 'ask',
      label: '"Free for a pub thing this week?"',
      playerText: 'free for a pub thing this week?',
      npcReply: 'YES. Thursday? 7pm? The Crown around the corner?',
      effect: { npc: { sarah: 1 }, flag: 'sarah_pub_arranged' },
    });
  }
  if (rel >= 3 && isFresh('sarah_ask_recipe', seen)) {
    opts.push({
      id: 'sarah_ask_recipe', kind: 'ask',
      label: '"What\'s your mum\'s shortbread recipe?"',
      playerText: "what's actually in your mum's shortbread? it's incredible",
      npcReply: "she'd murder me if I shared. but: butter is salted, the trick is freezing the dough 30 min first",
      effect: { npc: { sarah: 1 } },
    });
  }
  if (rel >= 4 && isFresh('sarah_ask_pancakes', seen) && week >= 18) {
    opts.push({
      id: 'sarah_ask_pancakes', kind: 'ask',
      label: '"Pancake Day this week — your kitchen?"',
      playerText: "pancake day's coming up. your kitchen this Tuesday?",
      npcReply: "OBVIOUSLY. I'll do batter, you bring lemon and complaints about my flipping",
      effect: { npc: { sarah: 1 } },
    });
  }
  if (rel >= 5 && isFresh('sarah_ask_homesick', seen)) {
    opts.push({
      id: 'sarah_ask_homesick', kind: 'ask',
      label: '"Do you ever miss home?"',
      playerText: 'random question — do you ever miss home? you\'re kinda close to it but still',
      npcReply: 'every week. mum being mum is also why I left, but I miss her cooking lol. you?',
      effect: { npc: { sarah: 2 } },
    });
  }
  if (rel >= 6 && flags.cotswolds_visited && isFresh('sarah_ask_dad', seen)) {
    opts.push({
      id: 'sarah_ask_dad', kind: 'ask',
      label: '"How\'s your dad doing?"',
      playerText: "how's your dad doing? hope his back's better",
      npcReply: "thanks for asking 🥹 he's ok. arthritis acting up. he asked about you actually.",
      effect: { npc: { sarah: 2 } },
    });
  }
  if (rel >= 7 && isFresh('sarah_invite_xmas', seen) && week >= 10 && week <= 13) {
    opts.push({
      id: 'sarah_invite_xmas', kind: 'ask',
      label: '"What are you doing for Christmas?"',
      playerText: "any plans for christmas? I might just stay in london",
      npcReply: 'oh god. come to Cotswolds. mum will adopt you. seriously 🌲',
      effect: { npc: { sarah: 2 }, flag: 'sarah_xmas_invited' },
    });
  }

  // ─── storyProgress hooks · 剧情完成后的"延续话题" ───
  // sarah_3 = Cotswolds 圣诞已访 → 下次见面话题
  if (sarahProgress >= 3 && flags.cotswolds_visited && isFresh('sarah_thanks_xmas', seen)) {
    opts.push({
      id: 'sarah_thanks_xmas', kind: 'reply',
      label: '"Btw — thanks for last Christmas"',
      playerText: "btw — never properly said it. thanks for the Cotswolds Christmas. that's the warmest I felt this year.",
      npcReply: "babe stop you'll make me cry on the tube. mum still asks about you weekly btw 🥹",
      effect: { npc: { sarah: 2 }, belonging: 8 },
    });
  }
  // sarah_4 = 凌晨 2 点电话已接 → "her break-up 后续"
  if (sarahProgress >= 4 && isFresh('sarah_check_breakup', seen)) {
    opts.push({
      id: 'sarah_check_breakup', kind: 'ask',
      label: '"How are you doing actually?"（认真问）',
      playerText: "real check-in — how are you actually doing since James?",
      npcReply: "honestly? better than I thought. you helped more than you know. drinks Friday?",
      effect: { npc: { sarah: 2 }, flag: 'sarah_pub_arranged' },
    });
  }

  // ─── weekPhase hooks · 不同阶段的合时宜话题 ───
  if (weekPhase === 'exam' && rel >= 3 && isFresh('sarah_exam_solidarity', seen)) {
    opts.push({
      id: 'sarah_exam_solidarity', kind: 'ask',
      label: '"how are exams going?"',
      playerText: "how are exams going? mine\'s tomorrow and I haven't slept",
      npcReply: "I have one tomorrow too. library 4F right now. join me. we suffer together 💀",
      effect: { npc: { sarah: 1 } },
    });
  }
  if (weekPhase === 'dissertation' && rel >= 4 && isFresh('sarah_diss_check', seen)) {
    opts.push({
      id: 'sarah_diss_check', kind: 'ask',
      label: '"diss going OK?"',
      playerText: "how's the dissertation? mine's a slow death",
      npcReply: 'word count says 4500. mood says I should drop out. you?',
      effect: { npc: { sarah: 1 } },
    });
  }
  if (weekPhase === 'spring' && rel >= 3 && week === 19 && isFresh('sarah_valentines', seen)) {
    opts.push({
      id: 'sarah_valentines', kind: 'reply',
      label: '"Forever Alone Party Friday?"',
      playerText: "valentine's friday. forever alone party? 中餐馆?",
      npcReply: "YES. james and I officially over so. £50 budget. who's bringing wine 🍷",
      effect: { npc: { sarah: 2 }, flag: 'sarah_valentine_arranged' },
    });
  }

  // ─── 玩家状态 hooks ───
  if (stats.energy <= 25 && isFresh('sarah_low_energy', seen)) {
    opts.push({
      id: 'sarah_low_energy', kind: 'reply',
      label: '"Honestly fried this week"',
      playerText: 'honestly fried this week. just venting',
      npcReply: rel >= 4
        ? 'babe come down. I have biscuits and we don\'t have to talk 🫂'
        : 'oh no — take a night off. shower + early bed seriously helps',
      effect: { npc: { sarah: 1 }, belonging: 4 },
    });
  }
  if (stats.belonging <= 20 && isFresh('sarah_lonely', seen)) {
    opts.push({
      id: 'sarah_lonely', kind: 'reply',
      label: '"Feeling pretty alone tbh"',
      playerText: "feeling pretty alone tbh. weird week",
      npcReply: rel >= 4
        ? "you're not alone. flat dinner tonight 7pm I'll cook. don't no-show me"
        : "that's so valid — london does that. we should grab coffee this week",
      effect: { npc: { sarah: 1 }, belonging: 6 },
    });
  }

  // ─── 剧情 hooks ───
  if ((flags.scammed_pig_full || flags.scammed_trading_full || flags.scammed_sponsor_full) &&
      !flags.sarah_knows_scam && isFresh('sarah_admit_scam', seen)) {
    opts.push({
      id: 'sarah_admit_scam', kind: 'reply',
      label: '"Actually... something happened"',
      playerText: "actually — something happened. can we talk?",
      npcReply: 'shit babe. tell me everything. coming to your door now 🏃‍♀️',
      effect: { npc: { sarah: 3 }, flag: 'sarah_knows_scam', belonging: 8 },
    });
  }
  if (flags.linnan_dating && rel >= 4 && !flags.sarah_knows_partner && isFresh('sarah_tell_partner', seen)) {
    opts.push({
      id: 'sarah_tell_partner', kind: 'reply',
      label: '"So... I started seeing someone"',
      playerText: "so — I should mention. I'm sort of seeing someone. cohort kid.",
      npcReply: "WAIT. YES. tell me EVERYTHING. flat dinner Friday, bring them",
      effect: { npc: { sarah: 2 }, flag: 'sarah_knows_partner' },
    });
  }

  // ─── 永远兜底 (repeatable smalltalk · 按 day/rel/weekPhase 轮换) ───
  opts.push({
    id: 'sarah_smalltalk_weather', kind: 'smalltalk',
    label: '"Lovely weather innit"',
    playerText: 'lovely weather innit 😏',
    npcReply: pickReply(ctx, [
      { when: c => c.npcRel?.sarah >= 5, replies: [
        'mate did you just',
        'you\'re too british for me babe. stop it.',
        'oh god you\'re passing the citizenship test.',
        'mum would adopt you. terrifying progress 🥲',
      ]},
      { replies: [
        'mate did you just',
        'haha. you\'re getting it.',
      ]},
    ]),
    effect: { npc: { sarah: 1 } },
  });
  opts.push({
    id: 'sarah_smalltalk_lecture', kind: 'smalltalk',
    label: '"How was lecture?"',
    playerText: 'how was lecture? I zoned out for 20 min',
    npcReply: pickReply(ctx, [
      { when: c => c.weekPhase === 'exam', replies: [
        'no lecture mate. exam week. I\'m living in 4F.',
        'cancelled — revision week. someone\'s buzzing on Whitmore\'s door tho.',
      ]},
      { when: c => c.weekPhase === 'dissertation', replies: [
        'no lectures babe — dissertation supervisor meetings only. how\'s yours going.',
        'we\'re past that stage 😭 it\'s just me + word doc + crying.',
      ]},
      { when: c => c.weekPhase === 'reading', replies: [
        'reading week — no lectures. I\'m using it to nap.',
        'reading week. mum thinks it\'s a holiday. it\'s not.',
      ]},
      { when: c => c.npcRel?.sarah >= 4, replies: [
        'same. Whitmore mentioned a paper I\'ll send you the cite',
        'genuinely lost the will to live at slide 47. you?',
        'tutor pronounced Foucault wrong AGAIN. I died.',
        'we did Said. tutor asked "what does the orient mean to you" 🫠',
      ]},
      { replies: [
        'same. Whitmore mentioned a paper I\'ll send you the cite',
        'fine I think. half the reading was optional thank god.',
        'three coffees in. brain liquefied. send help.',
      ]},
    ]),
    effect: {},
  });
  opts.push({
    id: 'sarah_smalltalk_food', kind: 'smalltalk',
    label: '"Pret or Tesco meal deal today?"',
    playerText: "pret or tesco meal deal today",
    npcReply: pickReply(ctx, [
      { when: c => c.weekPhase === 'dissertation', replies: [
        'tesco. I\'m mainlining meal deal til submission.',
        'meal deal x3. my body is 70% sandwich.',
      ]},
      { when: c => c.npcRel?.sarah >= 4, replies: [
        'tesco. I\'m down £30 on pret this week alone 😩',
        'pret. yes I have a problem. £15 today and counting.',
        'tesco — mum says I\'m wasting student loan on £4 sandwiches. she\'s right.',
        'pret. they know my order. that\'s how british I\'ve become.',
      ]},
      { replies: [
        'tesco. I\'m down £30 on pret this week alone 😩',
        'meal deal. crisp + sandwich + smoothie. the sacred trinity.',
        'pret today. £6 latte = personality.',
      ]},
    ]),
    effect: {},
  });

  return opts;
}

// ─────────────────────────────────────────────────────────────
// Mom · 妈妈 · belonging 主线
// ─────────────────────────────────────────────────────────────
function momOptions(ctx) {
  const { flags, thread, seen, week, stats = {}, storyProgress = {}, weekPhase } = ctx;
  const opts = [];

  // ─── 上下文回复 ───
  // 互斥：3 选 1 回应妈妈"到了吗"
  if (lastSaid(thread, '到了吗') && isFresh('mom_arrived', seen, 'mom_arrival')) {
    opts.push({
      id: 'mom_arrived', group: 'mom_arrival', kind: 'reply',
      label: '"妈我到了 一切都好"',
      playerText: '妈我到了 一切都好 别担心',
      npcReply: '哎好好 妈给你转 500 块过去 别省着 该吃就吃',
      effect: { belonging: 6 },
    });
    opts.push({
      id: 'mom_arrived_short', group: 'mom_arrival', kind: 'reply',
      label: '"嗯"（短）',
      playerText: '嗯',
      npcReply: '... 你这孩子能不能多打几个字 妈担心',
      effect: { belonging: -2 },
    });
    opts.push({
      id: 'mom_arrived_warm', group: 'mom_arrival', kind: 'reply',
      label: '"妈 飞机上一直想哭"',
      playerText: '妈 飞机上其实一直想哭。但是没敢让旁边的人看见',
      npcReply: '你这孩子。妈这边也不太好。别压着 想哭就哭。',
      effect: { belonging: 12 },
    });
  }
  // 互斥：感谢生活费 — 有 Mei 姐 job 时讲"我打工够花"，没有时讲"够用"
  if (lastSaid(thread, '生活费') && flags.mei_job &&
      isFresh('mom_thanks_stipend_job', seen, 'mom_stipend_reply')) {
    opts.push({
      id: 'mom_thanks_stipend_job', group: 'mom_stipend_reply', kind: 'reply',
      label: '"妈我够花 你别打这么多"',
      playerText: '妈 我这个月 Mei 姐店打工 够花了 你和爸自己花',
      npcReply: '你这孩子 妈这边没事 你别为我们省 该买的别舍不得',
      effect: { belonging: 8 },
    });
  }
  if (lastSaid(thread, '生活费') && !flags.mei_job &&
      isFresh('mom_thanks_stipend_basic', seen, 'mom_stipend_reply')) {
    opts.push({
      id: 'mom_thanks_stipend_basic', group: 'mom_stipend_reply', kind: 'reply',
      label: '"妈 收到了 你别担心"',
      playerText: '妈 收到了 这边够用 你和爸别舍不得花',
      npcReply: '你这孩子 妈这边没事 你别为我们省 该买的别舍不得',
      effect: { belonging: 8 },
    });
  }
  // ─── Proactive ping follow-ups ───
  // mom_low_belonging_check: "傻孩子 妈这边老是想你"
  if (lastSaid(thread, '老是想你') && isFresh('mom_lonely_x', seen, 'mom_lonely_reply')) {
    opts.push({
      id: 'mom_lonely_honest', group: 'mom_lonely_reply', kind: 'reply',
      label: '"妈我也想你 这边一个人"',
      playerText: '妈 我也想你 这边一个人 有时候挺难的',
      npcReply: '今晚视频。你做饭妈做饭 我们一起吃。你那边 8 点 我这边 4 点。',
      effect: { belonging: 18, flag: 'mom_video_scheduled' },
    });
    opts.push({
      id: 'mom_lonely_brush', group: 'mom_lonely_reply', kind: 'reply',
      label: '"没事妈 我挺好的"',
      playerText: '没事妈 我挺好的 别操心',
      npcReply: '妈知道你说\'挺好的\'通常就是不太好。等你想说的时候妈一直在。',
      effect: { belonging: 4 },
    });
  }
  // mom_pre_xmas_concern: "马上圣诞节了 你今年不回..."
  if (lastSaid(thread, '马上圣诞') && isFresh('mom_xmas_x', seen, 'mom_xmas_reply')) {
    opts.push({
      id: 'mom_xmas_thanks', group: 'mom_xmas_reply', kind: 'reply',
      label: '"妈别寄了 心意收到"',
      playerText: '妈 别寄了 寄到时候过期了。心意收到 我自己包饺子',
      npcReply: '行 那寄给你的不是饺子是别的 你猜 (妈不告诉你)',
      effect: { belonging: 10 },
    });
    opts.push({
      id: 'mom_xmas_book_flight', group: 'mom_xmas_reply', kind: 'reply',
      label: '"我看看圣诞机票"',
      playerText: '妈 我看看 圣诞机票 现在还来得及',
      npcReply: '哎呀好啊！妈给你去年衣服都洗好挂着等你。但是别为这事冲动 想清楚 dissertation 来不来得及',
      effect: { belonging: 14, flag: 'mom_xmas_invite_back' },
    });
  }
  // mom_after_brp: "妈看学校发的邮件 你 BRP 早就到了吧..."
  if (lastSaid(thread, '学校发的邮件') && isFresh('mom_brp_x', seen, 'mom_brp_reply')) {
    opts.push({
      id: 'mom_brp_apologize', group: 'mom_brp_reply', kind: 'reply',
      label: '"妈对不起 忘了说"',
      playerText: '妈 对不起 忘了告诉你 我拍照给你',
      npcReply: '行 妈不怪你 你忙。但是这种大事下次第一时间 妈想跟着开心',
      effect: { belonging: 8, flag: 'mom_brp_proactive' },
    });
  }

  if (lastSaid(thread, '500 块') && isFresh('mom_thanks_red_envelope', seen)) {
    opts.push({
      id: 'mom_thanks_red_envelope', kind: 'reply',
      label: '"妈 钱收到了 谢谢"',
      playerText: '妈 钱收到了 我请 Sarah 室友吃了顿饭 都很开心',
      npcReply: '哎呀好。室友是英国姑娘？人怎么样 别让她欺负你',
      effect: { belonging: 6 },
    });
  }

  // ─── 深度链 1 · 家人 / 父母（5 层）───
  if (isFresh('mom_ask_dad', seen)) {
    opts.push({
      id: 'mom_ask_dad', kind: 'ask',
      label: '"我爸最近怎么样"',
      playerText: '妈 我爸最近还好吗 他血压怎么样',
      npcReply: '你爸啊 老样子 不肯减酒。昨天还问我你冷不冷。这个老头 嘴上不说',
      effect: { belonging: 4 },
    });
  }
  if (isFresh('mom_ask_dad_drinking', seen)) {
    opts.push({
      id: 'mom_ask_dad_drinking', kind: 'ask',
      requires: ['mom_ask_dad'],
      label: '"妈 我爸喝得多吗"',
      playerText: '妈 我爸晚上还喝吗 喝多吗',
      npcReply: '一晚两瓶啤酒 我跟他说过 1 万次 没用。你劝劝他。他听你的。',
      effect: { belonging: 4 },
    });
  }
  if (week >= 10 && isFresh('mom_ask_marriage', seen)) {
    opts.push({
      id: 'mom_ask_marriage', kind: 'ask',
      requires: ['mom_ask_dad_drinking'],
      label: '"妈 你和我爸吵架吗"',
      playerText: '妈 你和我爸最近还吵吗',
      npcReply: '吵啊 上周还吵了一次 他要去同学聚会 我让他少喝 他不听。25 年了 也就这样。',
      effect: { belonging: 6 },
    });
  }
  if (week >= 14 && isFresh('mom_ask_young', seen)) {
    opts.push({
      id: 'mom_ask_young', kind: 'ask',
      requires: ['mom_ask_marriage'],
      label: '"妈 你年轻时是什么样"',
      playerText: '妈 你年轻时是什么样 我都没问过',
      npcReply: '哎呀 妈年轻时也算文艺女青年。喜欢看张爱玲 写过几首烂诗。后来嫁你爸 结婚生你 那些就放下了。',
      effect: { belonging: 10 },
    });
  }
  if (week >= 18 && isFresh('mom_ask_regret', seen)) {
    opts.push({
      id: 'mom_ask_regret', kind: 'ask',
      requires: ['mom_ask_young'],
      label: '"妈 你后悔过吗"',
      playerText: '妈 你这辈子有没有后悔过什么',
      npcReply: '后悔过几件。但生你不是其中之一。妈 22 岁的时候和你现在一样 不知道想要什么。妈那时候没人陪着说这些话。所以你现在跟妈说这些 妈很高兴。',
      effect: { belonging: 18, flag: 'mom_deep_talked' },
    });
  }
  if (isFresh('mom_ask_grandma', seen) && week >= 6) {
    opts.push({
      id: 'mom_ask_grandma', kind: 'ask',
      label: '"奶奶身体怎么样"',
      playerText: '妈 奶奶最近身体怎么样 我有时候梦见她',
      npcReply: '奶奶好。她还问妈你那边什么时候回来过年。妈跟她说大概不行了 她没说话',
      effect: { belonging: 8 },
    });
  }
  if (week >= 8 && isFresh('mom_call_back', seen)) {
    opts.push({
      id: 'mom_call_back', kind: 'ask',
      label: '"妈 今晚视频？"',
      playerText: '妈 今晚视频？我有点想跟你说说话',
      npcReply: '行 妈 8 点做完饭等你 你爸今晚也在',
      effect: { belonging: 10, flag: 'mom_video_scheduled' },
    });
  }
  if (week >= 14 && isFresh('mom_ask_recipe', seen)) {
    opts.push({
      id: 'mom_ask_recipe', kind: 'ask',
      label: '"妈 番茄炒蛋怎么做来着"',
      playerText: '妈 番茄炒蛋你怎么做的来着 我老忘记顺序',
      npcReply: '先打蛋加点盐和料酒 油热到冒烟 蛋下去 半熟立刻盛出来。番茄另起锅炒出汁 再把蛋倒回去 最后撒糖。糖是关键。',
      effect: { belonging: 6 },
    });
  }
  if (week >= 18 && isFresh('mom_ask_relatives', seen)) {
    opts.push({
      id: 'mom_ask_relatives', kind: 'ask',
      label: '"我表妹结婚了吗"',
      playerText: '妈 表妹的婚礼定下来了吗',
      npcReply: '5 月办。她让妈问你能不能回来。妈跟她说你 dissertation 走不开。',
      effect: { belonging: 4 },
    });
  }
  if (week >= 20 && isFresh('mom_career_pressure', seen)) {
    opts.push({
      id: 'mom_career_pressure', kind: 'ask',
      label: '"妈 你想我毕业回国吗"',
      playerText: '妈 说实话 你想我毕业回国吗',
      npcReply: '想。但更想你做让你心里平静的那个选择。妈不催。爸催的时候我会拦他。',
      effect: { belonging: 12 },
    });
  }
  // 互斥：邀请来 vs 婉拒（关键人生节点选择）
  if (week >= 30 && isFresh('mom_visit', seen, 'mom_visit_decision')) {
    opts.push({
      id: 'mom_ask_visit', group: 'mom_visit_decision', kind: 'ask',
      label: '"妈 你和爸要不要 4 月来伦敦"',
      playerText: '妈 你和爸要不要 4 月来伦敦 我带你们看看',
      npcReply: '哎呀 妈跟你爸商量一下 签证好办吗？',
      effect: { belonging: 6, flag: 'parents_invited' },
    });
    opts.push({
      id: 'mom_decline_visit', group: 'mom_visit_decision', kind: 'ask',
      label: '"妈 这学期太忙 你们别折腾了"',
      playerText: '妈 这学期 dissertation 太忙 你们别折腾签证 等我毕业回去',
      npcReply: '行 你说怎么就怎么。妈跟爸说不来。下次。',
      effect: { belonging: -3, flag: 'parents_declined' },
    });
  }
  if (week >= 44 && isFresh('mom_ask_after_grad', seen)) {
    opts.push({
      id: 'mom_ask_after_grad', kind: 'ask',
      label: '"妈 我毕业要不要先在英国试一年"',
      playerText: '妈 我毕业想先在英国试一年 PSW visa 给我两年时间',
      npcReply: '妈知道你早就想好了。你爸会念两句让他念。妈支持。但是别累坏自己。',
      effect: { belonging: 14, flag: 'mom_supports_psw' },
    });
  }

  // ─── weekPhase hooks · 妈也知道你处在哪个学期阶段 ───
  if (weekPhase === 'exam' && isFresh('mom_exam_pressure', seen)) {
    opts.push({
      id: 'mom_exam_pressure', kind: 'ask',
      label: '"妈 明天考试 紧张"',
      playerText: '妈 明天考试 我紧张得睡不着',
      npcReply: '深呼吸 你妈 1995 年 6 月 3 号也这样。复习够了就睡。考完给妈打电话',
      effect: { belonging: 10, energy: 3 },
    });
  }
  if (weekPhase === 'dissertation' && isFresh('mom_diss_pep_talk', seen)) {
    opts.push({
      id: 'mom_diss_pep_talk', kind: 'ask',
      label: '"妈 论文写不动"',
      playerText: '妈 论文写不动 我感觉我什么都不会',
      npcReply: '你能写到 dissertation 这一步 已经把比你妈这辈子读得书都多了。一天写 200 字就行。妈给你转笔奶茶钱',
      effect: { belonging: 12, energy: 5, wallet: 50 },
    });
  }
  // 圣诞 / 春节 阶段的妈
  if (weekPhase === 'xmas' && isFresh('mom_xmas_check', seen)) {
    opts.push({
      id: 'mom_xmas_check', kind: 'ask',
      label: '"妈 我自己一个人过圣诞"',
      playerText: '妈 我没回国 自己一个人过圣诞 你别担心',
      npcReply: '妈给你下了顿饺子 拍照给你看 你那边也吃点啥别凑合',
      effect: { belonging: 14 },
    });
  }

  // ─── 玩家状态 hooks ───
  if (stats.belonging <= 20 && isFresh('mom_low_belonging', seen)) {
    opts.push({
      id: 'mom_low_belonging', kind: 'ask',
      label: '"妈 我今天觉得很孤独"',
      playerText: '妈 今天有点孤独 没事就给你说一声',
      npcReply: '傻孩子 妈也是一个人在国外读过书的 这个感觉妈懂。视频吗 妈现在就开。',
      effect: { belonging: 16 },
    });
  }
  if (stats.energy <= 25 && isFresh('mom_low_energy', seen)) {
    opts.push({
      id: 'mom_low_energy', kind: 'ask',
      label: '"妈 我太累了"',
      playerText: '妈 我这周累爆了 dissertation 写不动',
      npcReply: '别熬。妈 1995 年硕士论文也是这个时候。睡 8 小时再写 比熬通宵质量高 3 倍。妈没骗你',
      effect: { belonging: 8, energy: 5 },
    });
  }
  if (stats.wallet <= -50 && isFresh('mom_low_wallet', seen)) {
    opts.push({
      id: 'mom_low_wallet', kind: 'ask',
      label: '"妈 这个月有点紧"',
      playerText: '妈 实话 这个月有点紧 你能再转点吗',
      npcReply: '当然。妈 5 分钟内转你 1000。下次紧别等到这种地步再说。',
      effect: { belonging: 6, wallet: 1000 },
    });
  }

  // ─── 剧情 hooks ───
  if ((flags.scammed_pig_full || flags.scammed_trading_full || flags.scammed_sponsor_full) &&
      !flags.mom_told_scam && isFresh('mom_admit_scam', seen)) {
    opts.push({
      id: 'mom_admit_scam', kind: 'reply',
      label: '"妈 我有件事一直没敢说..."',
      playerText: '妈 我有件事一直没敢说 我被骗了一笔钱 我现在没事 但我想告诉你',
      npcReply: '傻孩子 多少钱 别担心 妈给你转。下次有这种事第一时间打妈。妈不骂你',
      effect: { belonging: 18, flag: 'mom_told_scam', wallet: 500 },
    });
  }
  if (flags.linnan_dating && !flags.mom_knows_partner && isFresh('mom_tell_partner', seen)) {
    opts.push({
      id: 'mom_tell_partner', kind: 'ask',
      label: '"妈 我有 partner 了"',
      playerText: '妈 跟你说一件事 我有 partner 了 同班同学 杭州的',
      npcReply: '哎呀！什么时候带回家给妈看看？人脾气怎么样？爸妈条件呢？',
      effect: { belonging: 8, flag: 'mom_knows_partner' },
    });
  }
  if (flags.brp_collected && !flags.mom_brp_told && isFresh('mom_brp_done', seen)) {
    opts.push({
      id: 'mom_brp_done', kind: 'ask',
      label: '"妈 我 BRP 拿到手了"',
      playerText: '妈 BRP 卡今天拿到了 总算落地了',
      npcReply: '哎呀那可以。妈担心了一个月。拍张照妈给你爸看看',
      effect: { belonging: 6, flag: 'mom_brp_told' },
    });
  }

  // ─── 永远兜底 (repeatable) ───
  opts.push({
    id: 'mom_lovesick_msg', kind: 'smalltalk',
    label: '"妈 我有点想你"',
    playerText: '妈 我有点想你 没事就这一句',
    npcReply: pickReply(ctx, [
      { when: c => c.weekPhase === 'xmas', replies: [
        '哎呀傻孩子 妈也想你。今年妈准备的羊肉给你冷冻了 等你下次回来还能吃。',
        '想妈就视频。妈每天都开着 wifi 等你。',
        '哎呀都圣诞了 你那边肯定冷 妈给你寄的羽绒服收到没',
      ]},
      { when: c => c.stats?.belonging <= 30, replies: [
        '哎呀傻孩子 妈也想你。早点睡。别熬夜。听到了吗。',
        '妈给你打钱了 自己买点好吃的。一个人也别凑合。',
        '妈每天看你朋友圈 没更新就担心。视频一下吧',
      ]},
      { replies: [
        '哎呀傻孩子 妈也想你。早点睡。别熬夜。听到了吗。',
        '妈这边都好。等你回家。',
        '想妈就给妈打电话 别憋着',
      ]},
    ]),
    effect: { belonging: 12 },
  });
  opts.push({
    id: 'mom_smalltalk_weather', kind: 'smalltalk',
    label: '"妈 北京今天热吗"',
    playerText: '妈 北京今天天气怎么样',
    npcReply: pickReply(ctx, [
      // 按伦敦周对应国内大致月份（玩家 W1 = 9 月开学）
      { when: c => c.week >= 9 && c.week <= 18, replies: [
        '今天 5°C 雾霾 PM2.5 又爆了。你那边呢 多穿点',
        '北京冷得不像话 暖气还没开。你呢',
        '今天 8°C 阴天。妈给你寄的羽绒服收到没',
      ]},
      { when: c => c.week >= 19 && c.week <= 30, replies: [
        '今天 15°C 春天了 杨絮开始飞 妈每天戴口罩',
        '今天 18°C 晴。妈跟你阿姨下午去逛颐和园。',
        '今天 12°C 早晚温差大。多穿件外套。',
      ]},
      { when: c => c.week >= 31, replies: [
        '今天 33°C。空调没停过。你那边呢 别中暑',
        '今天 29°C 闷热。你伦敦凉快吧。',
        '今天 35°C 极端高温。你那边再热应该也没这么离谱',
      ]},
      { replies: [
        '今天 22°C 秋天最舒服的几天。你呢',
        '今天 26°C 还热。你伦敦冷了没',
        '今天 18°C 你那边肯定比这凉。多穿。',
      ]},
    ]),
    effect: { belonging: 2 },
  });
  opts.push({
    id: 'mom_smalltalk_food', kind: 'smalltalk',
    label: '"妈 今天什么菜"',
    playerText: '妈 今晚吃什么',
    npcReply: pickReply(ctx, [
      { when: c => c.weekPhase === 'xmas', replies: [
        '今天饺子 + 鱼香肉丝。你那边吃啥 别一个人凑合',
        '过年我做了八菜一汤 拍给你看 你眼馋',
        '今天涮羊肉 你不在 我和你爸两个人吃不完',
      ]},
      { when: c => c.flags?.mei_job, replies: [
        '红烧肉 + 西红柿炒蛋。Mei 姐做的肯定比妈好吃 哼',
        '今天清炒油菜。你都跟着 Mei 姐学手艺了 还问我',
        '糖醋排骨。你下次给我视频展示一下你 Mei 姐店里端盘子',
      ]},
      { replies: [
        '红烧肉 + 西红柿炒蛋。给你留一碗也吃不到 心疼。',
        '番茄牛腩面。妈给你留菜谱',
        '今天清蒸鱼。你呢 别老吃外卖',
        '炖鸡汤。专程给你爸炖的 你爸最近上火',
      ]},
    ]),
    effect: { belonging: 4 },
  });

  return opts;
}

// ─────────────────────────────────────────────────────────────
// Aditi · 互助线 (study buddy)
// ─────────────────────────────────────────────────────────────
function aditiOptions(ctx) {
  const { npcRel, flags, thread, seen, stats = {}, week, storyProgress = {}, weekPhase } = ctx;
  const rel = npcRel.aditi || 0;
  const aditiProgress = storyProgress.aditi || 0;
  const opts = [];

  // ─── 接 Aditi 最近发的 ───
  if (lastSaid(thread, 'coffee') && isFresh('aditi_coffee_thanks', seen)) {
    opts.push({
      id: 'aditi_coffee_thanks', kind: 'reply',
      label: '"Thanks — I needed that"',
      playerText: 'thanks Aditi. I needed that more than I knew.',
      npcReply: 'we both did. same time tomorrow?',
      effect: { npc: { aditi: 1 } },
    });
  }
  if (lastSaid(thread, 'methodology') && isFresh('aditi_swap_essay', seen)) {
    opts.push({
      id: 'aditi_swap_essay', kind: 'reply',
      label: '"Yes let\'s swap drafts"',
      playerText: "yes! send yours, I'll send mine. tonight 9pm?",
      npcReply: 'deal. lemon & ginger tea, library 4F.',
      effect: { npc: { aditi: 2 }, flag: 'aditi_essay_swap' },
    });
  }
  // ─── Proactive ping follow-ups ───
  // aditi_late_check_in: "haven't heard from you in a week..."
  if (lastSaid(thread, "heard from you") && isFresh('aditi_late_x', seen, 'aditi_late_reply')) {
    opts.push({
      id: 'aditi_late_yes', group: 'aditi_late_reply', kind: 'reply',
      label: '"yes — corner table tomorrow"',
      playerText: 'yes — corner table 4F 10am tomorrow. block 1 starts sharp.',
      npcReply: '🫡 see you. coffee on me to bribe you for more notes.',
      effect: { npc: { aditi: 1 } },
    });
    opts.push({
      id: 'aditi_late_no', group: 'aditi_late_reply', kind: 'reply',
      label: '"can\'t this week — sorry"',
      playerText: "can't this week — overwhelmed. soon though.",
      npcReply: 'fair. take care of you first. dm when ready.',
      effect: { belonging: 2 },
    });
  }
  // aditi_after_essay_swap: "your draft made me rewrite my whole intro"
  if (lastSaid(thread, 'rewrite my whole intro') && isFresh('aditi_swap_x', seen, 'aditi_swap_reply')) {
    opts.push({
      id: 'aditi_swap_chai', group: 'aditi_swap_reply', kind: 'reply',
      label: '"chai works. tomorrow library?"',
      playerText: 'chai works. tomorrow library 4F. you bring thermos.',
      npcReply: 'deal. and ginger biscuits. mum sent me a stash.',
      effect: { npc: { aditi: 1 } },
    });
  }
  if (lastSaid(thread, 'hospital') && isFresh('aditi_dad_support', seen)) {
    opts.push({
      id: 'aditi_dad_support', kind: 'reply',
      label: '"I\'m here. video call now?"',
      playerText: "I'm here. video call now?",
      npcReply: "yes. please. I haven't told anyone else.",
      effect: { npc: { aditi: 4 }, belonging: 8 },
    });
  }

  // ─── 主动联系 ───
  if (rel >= 2 && isFresh('aditi_ask_lecture_share', seen)) {
    opts.push({
      id: 'aditi_ask_lecture_share', kind: 'ask',
      label: '"Did you understand today\'s lecture?"',
      playerText: "did you actually follow today's lecture? lost me at the Foucault bit",
      npcReply: "lost me too tbh. let's compare notes Library 4F at 6?",
      effect: { npc: { aditi: 1 } },
    });
  }
  // ─── 深度链 1 · 印度文化 / 家人（4 层）───
  if (rel >= 3 && isFresh('aditi_ask_chai', seen)) {
    opts.push({
      id: 'aditi_ask_chai', kind: 'ask',
      label: '"Teach me how to make chai?"',
      playerText: 'your chai is haunting me. teach me how?',
      npcReply: 'OH MY GOD yes. cardamom is non-negotiable. weekend at mine?',
      effect: { npc: { aditi: 2 }, flag: 'aditi_teach_chai' },
    });
  }
  if (rel >= 4 && isFresh('aditi_ask_indian_food', seen)) {
    opts.push({
      id: 'aditi_ask_indian_food', kind: 'ask',
      requires: ['aditi_ask_chai'],
      label: '"What\'s your mum\'s best dish?"',
      playerText: "what does your mum cook that you miss most?",
      npcReply: "okra fry. she does it with kalonji and it's life-changing. I keep trying to recreate it. always 70% there.",
      effect: { npc: { aditi: 1 } },
    });
  }
  if (rel >= 5 && isFresh('aditi_ask_family_back_home', seen)) {
    opts.push({
      id: 'aditi_ask_family_back_home', kind: 'ask',
      requires: ['aditi_ask_indian_food'],
      label: '"Tell me about your siblings"',
      playerText: "do you have siblings? you've never said",
      npcReply: 'one cousin who\'s basically my sister — she\'s the one I called when dad got sick. she\'s the only person who really knew.',
      effect: { npc: { aditi: 2 }, flag: 'aditi_cousin_close' },
    });
  }
  // ─── storyProgress hooks · 主线章节完成后的延续话题 ───
  if (aditiProgress >= 2 && flags.aditi_essay_swap && isFresh('aditi_post_swap_thanks', seen)) {
    opts.push({
      id: 'aditi_post_swap_thanks', kind: 'reply',
      label: '"Your draft taught me something"',
      playerText: "your draft taught me something — your method section is genuinely better than what I had",
      npcReply: "stop it 😭 actually keep doing this. weekly draft swap?",
      effect: { npc: { aditi: 2 }, flag: 'aditi_weekly_swap' },
    });
  }
  if (aditiProgress >= 3 && isFresh('aditi_after_video_call', seen)) {
    opts.push({
      id: 'aditi_after_video_call', kind: 'reply',
      label: '"I\'m glad you called that night"',
      playerText: "I'm glad you called me that night about your dad",
      npcReply: "you know what? me too. you didn't say much. you just stayed. that's the thing nobody teaches.",
      effect: { npc: { aditi: 3 }, belonging: 8 },
    });
  }
  if (aditiProgress >= 4 && flags.aditi_teach_chai && isFresh('aditi_after_cooking_night', seen)) {
    opts.push({
      id: 'aditi_after_cooking_night', kind: 'ask',
      label: '"Same time next weekend?"',
      playerText: 'same time next weekend? cardamom + soy sauce kitchen night',
      npcReply: "this is now a contractual obligation. yes 🌶️",
      effect: { npc: { aditi: 1 } },
    });
  }
  if (rel >= 7 && flags.aditi_cousin_close && isFresh('aditi_invite_meet_cousin', seen)) {
    opts.push({
      id: 'aditi_invite_meet_cousin', kind: 'ask',
      requires: ['aditi_ask_family_back_home'],
      label: '"Want to introduce me to your cousin (video)?"',
      playerText: "honestly — I want to meet your cousin. video call sometime?",
      npcReply: "she\'ll cry. I might too. yes. weekend works for her — she\'s 5.5h ahead. I\'ll set it up.",
      effect: { npc: { aditi: 3 }, belonging: 12, flag: 'aditi_cousin_met' },
    });
  }
  if (rel >= 4 && isFresh('aditi_ask_diwali', seen) && week >= 6 && week <= 10) {
    opts.push({
      id: 'aditi_ask_diwali', kind: 'ask',
      label: '"Tell me about Diwali?"',
      playerText: 'random question — what\'s Diwali like back home? saw your IG and got curious',
      npcReply: "honestly the WhatsApp is brutal — 200 unread. fireworks 'til 3am. mum still bullies me about not being there 🪔",
      effect: { npc: { aditi: 1 } },
    });
  }
  if (rel >= 5 && isFresh('aditi_ask_dad', seen)) {
    opts.push({
      id: 'aditi_ask_dad', kind: 'ask',
      label: '"How\'s your dad doing?"',
      playerText: 'hey. how\'s your dad?',
      npcReply: "asked stable. mum still not sleeping. thanks for asking 💜",
      effect: { npc: { aditi: 2 } },
    });
  }
  if (rel >= 6 && isFresh('aditi_ask_dissertation', seen) && week >= 38) {
    opts.push({
      id: 'aditi_ask_dissertation', kind: 'ask',
      label: '"Parallel writing tomorrow?"',
      playerText: 'library tomorrow? 90-min Pomodoro blocks. phones face down. loser buys lunch?',
      npcReply: "BLOCK 1 starts 10am sharp. you're going to lose 😏",
      effect: { npc: { aditi: 1 }, flag: 'diss_writing_pact_pre' },
    });
  }
  if (rel >= 7 && isFresh('aditi_ask_phd', seen) && week >= 36) {
    opts.push({
      id: 'aditi_ask_phd', kind: 'ask',
      label: '"Are you considering staying for PhD?"',
      playerText: 'real talk — are you doing PhD applications?',
      npcReply: "yes. UCL and Edinburgh. terrified. you?",
      effect: { npc: { aditi: 1 }, flag: 'aditi_phd_track' },
    });
  }

  // ─── 状态 hooks ───
  if (stats.energy <= 25 && isFresh('aditi_vent_tired', seen)) {
    opts.push({
      id: 'aditi_vent_tired', kind: 'reply',
      label: '"I\'m so done this week"',
      playerText: "honestly I'm so done this week",
      npcReply: rel >= 4
        ? "library 4F 9pm. I'm bringing biscuits. we don't have to study, just sit"
        : "same. one more week then we breathe.",
      effect: { npc: { aditi: 1 }, belonging: 4 },
    });
  }
  if (stats.belonging <= 22 && rel >= 3 && isFresh('aditi_lonely', seen)) {
    opts.push({
      id: 'aditi_lonely', kind: 'reply',
      label: '"Feeling out of place lately"',
      playerText: 'random — feeling out of place lately. just venting',
      npcReply: "I get it. let's grab proper dinner this week. somewhere quiet. you pick.",
      effect: { npc: { aditi: 1 }, belonging: 6 },
    });
  }

  // ─── 剧情 hooks ───
  if ((flags.scammed_pig_full || flags.scammed_trading_full) &&
      !flags.aditi_knows_scam && rel >= 4 && isFresh('aditi_admit_scam', seen)) {
    opts.push({
      id: 'aditi_admit_scam', kind: 'reply',
      label: '"Hey... can I tell you something heavy?"',
      playerText: "hey — can I tell you something heavy? I got scammed.",
      npcReply: "of course. tell me everything. my cousin had this — you're not alone in this.",
      effect: { npc: { aditi: 3 }, flag: 'aditi_knows_scam', belonging: 8 },
    });
  }

  // ─── 兜底 · repeatable，按 weekPhase / storyProgress / rel 轮换 ───
  opts.push({
    id: 'aditi_smalltalk_reading', kind: 'smalltalk',
    label: '"How\'s your reading list?"',
    playerText: "reading list killing you?",
    npcReply: pickReply(ctx, [
      { when: c => c.weekPhase === 'dissertation', replies: [
        'reading list? babe we\'re past that. it\'s just me + my own bibliography spiral.',
        'I\'ve read the same Foucault chapter 4 times. each time it gets less clear.',
      ]},
      { when: c => c.weekPhase === 'exam', replies: [
        'killing me 💀 also exams. compound trauma.',
        'I\'ve made flashcards for 6 hours and remembered 3 things.',
      ]},
      { when: c => (c.storyProgress?.aditi || 0) >= 3, replies: [
        'killing me 💀 you?',
        'finished 60%. mum keeps calling so progress slowed.',
        'made it through Said. now staring at Spivak like she\'s a final boss.',
        'reading instead of sleeping. obvious choice.',
      ]},
      { replies: [
        'killing me 💀 you?',
        'genuinely 200 pages behind. classic.',
        '40% done. 60% panic.',
      ]},
    ]),
    effect: {},
  });
  opts.push({
    id: 'aditi_smalltalk_lib', kind: 'smalltalk',
    label: '"Library 4F seat saved?"',
    playerText: 'are you in 4F? save me the corner table?',
    npcReply: pickReply(ctx, [
      { when: c => c.weekPhase === 'exam', replies: [
        'no seats anywhere mate, exam week. I\'m camping on a floor cushion.',
        'every seat taken. someone\'s SLEEPING under the 4F window.',
      ]},
      { when: c => c.weekPhase === 'dissertation', replies: [
        '4F is fully zombie mode. I saved you the one with the plug.',
        'window seat is yours. thermos of chai on standby.',
      ]},
      { when: c => (c.npcRel?.aditi || 0) >= 5, replies: [
        "yep. window seat. coffee\'s already on yours ☕",
        '4F corner is ours. brought ginger biscuits — share or perish.',
        'window seat saved. someone tried to take it. I gave them The Look.',
        '4F. brought 2 thermos. cardamom + plain. pick your fighter.',
      ]},
      { replies: [
        'yep window seat. come whenever.',
        '4F. plug socket works today (suspicious).',
        '3F today — 4F too loud. weird.',
      ]},
    ]),
    effect: { npc: { aditi: 1 } },
  });
  return opts;
}

// ─────────────────────────────────────────────────────────────
// Wangkai · 创业线
// ─────────────────────────────────────────────────────────────
function wangkaiOptions(ctx) {
  const { npcRel, flags, thread, seen, stats = {}, storyProgress = {} } = ctx;
  const rel = npcRel.wangkai || 0;
  const wkProgress = storyProgress.wangkai || 0;
  const opts = [];

  // ─── storyProgress hooks ───
  if (wkProgress >= 3 && flags.wangkai_business && isFresh('wk_after_business_open', seen)) {
    opts.push({
      id: 'wk_after_business_open', kind: 'reply',
      label: '"哥 那 10% 我别拿了 你启动资金"',
      playerText: '哥 那 10% 我别拿了 算我入伙先借给你做启动资金',
      npcReply: '...靠。哥们这话我记一辈子。我跟你说不行 你吃饭谁付。咱们等 6 月分账',
      effect: { npc: { wangkai: 3 }, belonging: 8 },
    });
  }
  if (wkProgress >= 4 && isFresh('wk_after_first_review', seen)) {
    opts.push({
      id: 'wk_after_first_review', kind: 'reply',
      label: '"哥 差评的事 我学到了"',
      playerText: '哥 上次那个 1 星差评 让我意识到生意是什么了',
      npcReply: '哥们 你看明白了。生意不是赚钱 是 \'被人 dislike 还要保持基本素质\'。你 OK 的',
      effect: { npc: { wangkai: 2 } },
    });
  }
  if (wkProgress >= 5 && flags.returned_with_wk && isFresh('wk_post_return_china', seen)) {
    opts.push({
      id: 'wk_post_return_china', kind: 'ask',
      label: '"哥 准备好了吗"',
      playerText: '哥 我们国内铺面下周交钥匙 你准备好了吗',
      npcReply: '靠 我每晚 4 点睡。但是有你 我知道 OK。',
      effect: { npc: { wangkai: 2 } },
    });
  }

  // ─── Proactive ping follow-ups ───
  // wk_referral_followup: "哥 我表哥那边面试咋样"
  if (lastSaid(thread, '面试咋样') && isFresh('wk_referral_x', seen, 'wk_referral_reply')) {
    opts.push({
      id: 'wk_referral_good', group: 'wk_referral_reply', kind: 'reply',
      label: '"哥 给你长脸了 第二轮"',
      playerText: '哥 进第二轮了 谢哥引荐',
      npcReply: '靠 我就知道。下周二我请你 Soho 海底捞 庆祝',
      effect: { npc: { wangkai: 2 }, belonging: 8 },
    });
    opts.push({
      id: 'wk_referral_bad', group: 'wk_referral_reply', kind: 'reply',
      label: '"哥 第一轮 ko 了"',
      playerText: '哥 第一轮就 ko 了 给你丢脸了',
      npcReply: '哥们这种事很正常。我表哥那个 partner 比较严。下次再 try。哥们你 reliable 这个评价跑不掉',
      effect: { npc: { wangkai: 1 } },
    });
    opts.push({
      id: 'wk_referral_pending', group: 'wk_referral_reply', kind: 'reply',
      label: '"还在等结果"',
      playerText: '哥 还在等 第二轮 5 天后',
      npcReply: '行 静等 别 over-think。结果出来给我消息',
      effect: { npc: { wangkai: 1 } },
    });
  }
  // wk_business_open: "净赚 £820 你那 10% 等下转你"
  if (lastSaid(thread, '净赚') && isFresh('wk_payout_x', seen, 'wk_payout_reply')) {
    opts.push({
      id: 'wk_payout_decline', group: 'wk_payout_reply', kind: 'reply',
      label: '"哥 不用 你留着启动资金"',
      playerText: '哥 不用 这一波我不要 你留着扩二店',
      npcReply: '哥们 哥们 哥们 这话我记一辈子。下个月分账 你不要拒。',
      effect: { npc: { wangkai: 3 }, belonging: 10, flag: 'wk_first_paycheck' },
    });
    opts.push({
      id: 'wk_payout_accept', group: 'wk_payout_reply', kind: 'reply',
      label: '"哥 谢了 我收下"',
      playerText: '哥 谢了 我收下 这是我第一笔分红',
      npcReply: '应该的 哥们 你 PSW 那时候我们再 reinvent 一次',
      effect: { npc: { wangkai: 1 }, wallet: 82, flag: 'wk_first_paycheck' },
    });
  }

  if (lastSaid(thread, 'Bicester') && isFresh('wk_yes_bicester', seen)) {
    opts.push({
      id: 'wk_yes_bicester', kind: 'reply',
      label: '"行 哥 周六见"',
      playerText: '行 哥 周六见 几点几分 哪个 coach',
      npcReply: 'Victoria coach 8:30 我提前订票 你来就行',
      effect: { npc: { wangkai: 1 }, flag: 'wk_bicester_pending' },
    });
  }
  if (lastSaid(thread, '奶茶') && rel >= 4 && isFresh('wk_visit_shop', seen)) {
    opts.push({
      id: 'wk_visit_shop', kind: 'ask',
      label: '"哥 我下午去店里看看"',
      playerText: '哥 我下午没事 去店里看你忙不忙',
      npcReply: '来 哥们 我留杯免费的给你试新口味',
      effect: { npc: { wangkai: 1 } },
    });
  }
  // ─── 深度链 · 职业 / 商业（4 层）───
  if (rel >= 5 && isFresh('wk_ask_advice_career', seen)) {
    opts.push({
      id: 'wk_ask_advice_career', kind: 'ask',
      label: '"哥 freelance 还是 corporate"',
      playerText: '哥 我最近在想毕业要不要走 freelance 不进 corporate 你怎么看',
      npcReply: '看你愿意承担多少 risk 哥们。你 reliable 我看出来了 要试就试。但记住 freelance 是 24/7 自己 cover 自己 没 mum cushion',
      effect: { npc: { wangkai: 2 } },
    });
  }
  if (rel >= 6 && isFresh('wk_ask_first_year', seen)) {
    opts.push({
      id: 'wk_ask_first_year', kind: 'ask',
      requires: ['wk_ask_advice_career'],
      label: '"哥 你 freelance 第一年怎么活下来的"',
      playerText: '哥 你 PhD 第一年也搞副业 那你怎么撑下来的',
      npcReply: '前 6 个月没收入 啃了 5 万人民币积蓄。第 7 个月接到第一个真实 client £1500 我哭了一天。说真的 哥们 这条路不光鲜',
      effect: { npc: { wangkai: 1 }, flag: 'wk_real_talked' },
    });
  }
  if (rel >= 7 && flags.wk_real_talked && isFresh('wk_ask_intro_client', seen)) {
    opts.push({
      id: 'wk_ask_intro_client', kind: 'ask',
      requires: ['wk_ask_first_year'],
      label: '"哥 你能 intro 我一个 client 吗"',
      playerText: '哥 我跟你说真的 我想试 freelance design 你能 intro 我一个 client 吗',
      npcReply: '行 我表姐那个 startup 缺 designer 我下午发你她联系方式 你别砸我面子哥们',
      effect: { npc: { wangkai: 2 }, flag: 'wk_intro_client', wallet: 0 },
    });
  }
  if (rel >= 8 && flags.wk_intro_client && isFresh('wk_ask_partnership', seen)) {
    opts.push({
      id: 'wk_ask_partnership', kind: 'ask',
      requires: ['wk_ask_intro_client'],
      label: '"哥 我们以后一起搞个事"',
      playerText: '哥 等我 PSW 拿到 我想跟你一起搞个 design + tea brand 联名 你看怎么样',
      npcReply: '哥们 你这话我等了一年。明天 Soho 我请你吃饭咱们认真聊',
      effect: { npc: { wangkai: 3 }, flag: 'wk_partnership_pact', belonging: 14 },
    });
  }
  // 状态 hook: 玩家钱紧 → 王凯主动 offer 跑腿
  if (stats.wallet <= -50 && rel >= 3 && isFresh('wk_offer_gig', seen)) {
    opts.push({
      id: 'wk_offer_gig', kind: 'reply',
      label: '"哥 这周钱紧 有活吗"',
      playerText: '哥 这周钱有点紧 你那边有什么活我能干',
      npcReply: '正好 周末店里 8 点高峰需要人贴标签 + 端外卖 £80 / 6 小时 来不',
      effect: { npc: { wangkai: 1 } },
    });
  }

  // ─── 兜底 · repeatable，按 storyProgress / 业务 flag 轮换 ───
  opts.push({
    id: 'wk_smalltalk_busy', kind: 'smalltalk',
    label: '"哥 最近店忙吗"',
    playerText: '哥 最近店忙吗',
    npcReply: pickReply(ctx, [
      { when: c => c.flags?.wangkai_business && c.week >= 30, replies: [
        '靠 这周外卖单破 600 我快被自己 hire 死了。',
        '稳定了 现在每天 7-12 点 peak。我招了 1 个学妹兼职。',
        '上礼拜 Eater London 给我们写了 paragraph 客流增 30%。哥们打钱准备扩二店。',
        '本周 PnL 终于 black ink 了。我哭了一晚上 然后又喝 3 杯抹茶。',
      ]},
      { when: c => c.flags?.wangkai_business, replies: [
        '靠 没停过。哥们你赶紧来帮我贴标签 😩',
        '今天外卖 80 单 我一个人贴标签贴到手指麻。',
        '凌晨 2 点了 我还在算账。哥们 你 PhD 第二年学的 excel 教教我',
        '稳得很 但有客户给我 1 星 因为珍珠太多。我要 911 自己。',
      ]},
      { when: c => (c.storyProgress?.wangkai || 0) >= 3, replies: [
        '哥们 开张倒计时。我每天 4 点睡 5 点醒 焦虑得不像话',
        '装修师傅又跑了。哥们这个国家 contractor 比英国天气还不可靠',
        'food hygiene certificate 申请了第 3 次 才批。靠',
      ]},
      { when: c => (c.storyProgress?.wangkai || 0) >= 2, replies: [
        '哥们 Bicester 那种活我代购了 8 趟 攒了 £400 启动资金',
        '在找铺位。Soho 一个 30 平方一年 £30k 抢手得离谱。',
        '我表哥在国内帮我找供应商 这周给我打了 3 次电话',
      ]},
      { replies: [
        '哥们 我 PhD 这周 deadline 4 个 我快疯了',
        'PhD 第二年开始爽了 supervisor 不催 我也不催自己',
        '哥们 我天天 SOAS 9 楼 你 4 楼 错开了',
      ]},
    ]),
    effect: {},
  });
  opts.push({
    id: 'wk_smalltalk_milk_tea', kind: 'smalltalk',
    label: '"哥 这周新口味是什么"',
    playerText: '哥 这周店里上什么新口味',
    npcReply: pickReply(ctx, [
      { when: c => c.flags?.wangkai_business && c.week >= 24, replies: [
        '芋圆紫薯燕麦奶。我喝了 4 杯试 老子又胖了',
        '陈皮普洱奶茶。客户问我陈皮是啥 我说"orange peel" 然后他们说"sounds fancy 加个 size"',
        '杨枝甘露 加芒果 + 西米 + 椰浆。Lily 在小红书帮我推 卖爆了',
        '抹茶生椰拿铁 不甜版。结果排队的都是 35+ 白人女士。',
        '黑糖珍珠鲜奶。配方是我妈给的。我妈不知道我开店。',
      ]},
      { when: c => c.flags?.wangkai_business, replies: [
        '芋圆紫薯燕麦奶。我喝了 4 杯试 老子又胖了',
        '焦糖布丁奶盖。试做 30 杯倒了一半 一半员工偷喝。',
        '冰镇荔枝乌龙。这周伦敦突然热了 卖爆。',
      ]},
      { when: c => (c.storyProgress?.wangkai || 0) >= 3, replies: [
        '哥们 我店还没开 哪有什么新口味 但我在试配方 你愿意当 alpha tester？',
        '配方还在 R&D 阶段。我 ensuite 厨房像化学实验室 mark 已经投诉了。',
      ]},
      { replies: [
        '哈？哥们我哪有店 我 PhD 学生',
        '哥们 我喝奶茶都得自己买 别问我业内消息',
        '哎呀奶茶这种东西 你自己买啊 别问我',
      ]},
    ]),
    effect: {},
  });
  return opts;
}

// ─────────────────────────────────────────────────────────────
// Mei 姐 · 温情线
// ─────────────────────────────────────────────────────────────
function meiOptions(ctx) {
  const { npcRel, flags, thread, seen, stats = {}, storyProgress = {} } = ctx;
  const rel = npcRel.mei || 0;
  const meiProgress = storyProgress.mei || 0;
  const opts = [];

  // ─── storyProgress hooks ───
  if (meiProgress >= 2 && flags.mei_job && isFresh('mei_post_job_thanks', seen)) {
    opts.push({
      id: 'mei_post_job_thanks', kind: 'ask',
      label: '"姐 周日要我多干一会吗"',
      playerText: '姐 周日要我多干一会吗 我不忙',
      npcReply: '行。10 点到 8 点。给你算 1.5 倍。带饭。',
      effect: { npc: { mei: 1 }, wallet: 0 },
    });
  }
  if (meiProgress >= 3 && isFresh('mei_post_story_quiet', seen)) {
    opts.push({
      id: 'mei_post_story_quiet', kind: 'reply',
      label: '"姐 上次那个茶 我喝着想了 3 天"',
      playerText: '姐 上次打烊后那杯茶 我喝着想了 3 天 谢谢',
      npcReply: '...傻孩子。下次再来 别忘了。',
      effect: { npc: { mei: 2 }, belonging: 6 },
    });
  }

  // ─── Proactive ping follow-ups ───
  // mei_post_scam_intuition: "傻孩子 你三天没来吃饭..."
  if (lastSaid(thread, '三天没来') && !flags.mei_knows_scam &&
      isFresh('mei_3days_x', seen, 'mei_3days_reply')) {
    opts.push({
      id: 'mei_3days_open', group: 'mei_3days_reply', kind: 'reply',
      label: '"姐 我跟你说件事..."',
      playerText: '姐 实话 我跟你说件事 不知道怎么开口',
      npcReply: '不用开口。你来。坐下。姐先给你盛饭再说。',
      effect: { npc: { mei: 4 }, flag: 'mei_knows_scam', belonging: 14 },
    });
    opts.push({
      id: 'mei_3days_lie', group: 'mei_3days_reply', kind: 'reply',
      label: '"姐 dissertation 没空"',
      playerText: '姐 dissertation 太忙 没空过来',
      npcReply: '行。今天来不了 明天再说。姐留着饭。',
      effect: { npc: { mei: 0 } },
    });
  }
  // mei_winter_concern: "伦敦冷得不像话..."
  if (lastSaid(thread, '冷得不像话') && isFresh('mei_winter_x', seen, 'mei_winter_reply')) {
    opts.push({
      id: 'mei_winter_yes', group: 'mei_winter_reply', kind: 'reply',
      label: '"姐 周日来羊肉锅"',
      playerText: '姐 周日来 羊肉锅听到就馋',
      npcReply: '6 点。带胃口。',
      effect: { npc: { mei: 1 } },
    });
  }

  if (lastSaid(thread, '吃饭') && isFresh('mei_yes_dinner', seen)) {
    opts.push({
      id: 'mei_yes_dinner', kind: 'reply',
      label: '"好的 姐 周日来"',
      playerText: '好的 姐 周日我过去 帮你择菜也行',
      npcReply: '哎呀这孩子真是 来就来 别帮忙 你坐着',
      effect: { npc: { mei: 1 }, flag: 'mei_sunday_visit' },
    });
  }
  if (rel >= 4 && flags.mei_job && isFresh('mei_ask_shifts', seen)) {
    opts.push({
      id: 'mei_ask_shifts', kind: 'ask',
      label: '"姐 这周还要人吗"',
      playerText: '姐 这周末店里还要人吗 我能来',
      npcReply: '要 周六晚 6 点来 8 点高峰 你帮我端盘子',
      effect: { npc: { mei: 1 } },
    });
  }
  if (flags.scammed_pig_full || flags.scammed_trading_full) {
    if (!flags.mei_knows_scam && isFresh('mei_admit_scam', seen)) {
      opts.push({
        id: 'mei_admit_scam', kind: 'reply',
        label: '"姐 我有件事..."',
        playerText: '姐 我跟你说件事 我被骗了一笔钱 我没敢告诉我妈',
        npcReply: '傻孩子。下午来店里 我们坐下说。姐 1996 年也被骗过 £3000 你听过吗',
        effect: { npc: { mei: 3 }, flag: 'mei_knows_scam', belonging: 18 },
      });
    }
  }
  // ─── 深度链 · Mei 姐的过去（4 层）───
  if (rel >= 5 && isFresh('mei_ask_old_days', seen)) {
    opts.push({
      id: 'mei_ask_old_days', kind: 'ask',
      label: '"姐 你刚来英国那几年"',
      playerText: '姐 你刚来英国那几年是什么样',
      npcReply: '哎 你别问 一两句说不清。下次来店里坐 姐慢慢跟你讲',
      effect: { npc: { mei: 1 } },
    });
  }
  if (rel >= 6 && isFresh('mei_ask_homeland', seen)) {
    opts.push({
      id: 'mei_ask_homeland', kind: 'ask',
      requires: ['mei_ask_old_days'],
      label: '"姐 你福建老家是哪个县"',
      playerText: '姐 你福建老家是哪儿 你跟我讲',
      npcReply: '福建莆田。30 年没回去了。爹妈走了。妹妹去年生了个孩子 妈我都没见过她长什么样。',
      effect: { npc: { mei: 2 }, belonging: 6 },
    });
  }
  if (rel >= 7 && isFresh('mei_ask_kids', seen)) {
    opts.push({
      id: 'mei_ask_kids', kind: 'ask',
      requires: ['mei_ask_homeland'],
      label: '"姐 你儿子们怎么样"',
      playerText: '姐 你两个儿子最近怎么样',
      npcReply: '老大读 sixth form 数学好。老二还小。哎 但是他们都不太会说中文了。我跟他们说话他们听不懂一半。',
      effect: { npc: { mei: 2 }, belonging: 8 },
    });
  }
  if (rel >= 8 && isFresh('mei_ask_regret_immigrant', seen)) {
    opts.push({
      id: 'mei_ask_regret_immigrant', kind: 'ask',
      requires: ['mei_ask_kids'],
      label: '"姐 你后悔出来吗"',
      playerText: '姐 你后悔当年出来吗',
      npcReply: '后悔不后悔早就过了那个阶段。30 年 哪有什么如果。但是看你这些刚来的孩子 姐有时候想 — 如果能跟年轻时候的自己说一句话 那就是 别一个人扛 别等别人来问 你主动找姐。所以姐每次看到你 都帮一勺。明白吗。',
      effect: { npc: { mei: 4 }, belonging: 22, flag: 'mei_deep_revealed' },
    });
  }

  // 状态 hook: 玩家精力低 → Mei 姐心疼
  if (stats.energy <= 25 && rel >= 3 && isFresh('mei_low_energy', seen)) {
    opts.push({
      id: 'mei_low_energy', kind: 'ask',
      label: '"姐 我这周特别累"',
      playerText: '姐 我这周特别累 不想动',
      npcReply: '傻孩子。下午来店里 我给你做一碗鸡汤面 不要钱。你别熬。听姐的。',
      effect: { npc: { mei: 1 }, belonging: 8, energy: 5 },
    });
  }
  if (stats.belonging <= 22 && rel >= 4 && isFresh('mei_lonely', seen)) {
    opts.push({
      id: 'mei_lonely', kind: 'ask',
      label: '"姐 一个人有点闷"',
      playerText: '姐 一个人有点闷',
      npcReply: '来店里坐。客人不多。姐陪你说话。',
      effect: { npc: { mei: 1 }, belonging: 12 },
    });
  }

  // ─── 兜底 · repeatable，按 day / rel / season 轮换回复 ───
  // 「今天什么菜」按季节 + day 轮换菜单；rel 越高，回复越像家人。
  opts.push({
    id: 'mei_smalltalk_today', kind: 'smalltalk',
    label: '"姐 今天什么菜"',
    playerText: '姐 今天什么特价',
    npcReply: pickReply(ctx, [
      { when: c => c.week >= 38 && c.npcRel?.mei >= 5, replies: [
        '今天炒苦瓜配排骨汤。你要降火 多端一碗。',
        '今天香酥鸭 你吃完别走 姐给你打包。',
        '今天黄焖鸡米饭 学校太累了吧 多加一根香肠。',
        '今天酸菜鱼 你最近瘦了 吃多点。',
      ]},
      { when: c => c.week >= 38, replies: [
        '今天香酥鸭 学生折扣 £6.50。',
        '今天炒苦瓜配排骨汤 适合熬夜的孩子。',
        '今天酸菜鱼 一份 £8 来吗。',
      ]},
      { when: c => c.week >= 24 && c.npcRel?.mei >= 5, replies: [
        '今天红烧狮子头 给你多打一勺。',
        '今天油焖大虾 你来就给你留 2 只大的。',
        '今天回锅肉 你最近脸色不太好 多吃两块。',
        '今天宫保鸡丁 我老公说今天的火候到了。',
      ]},
      { when: c => c.week >= 24, replies: [
        '今天红烧肉 排骨汤。',
        '今天宫保鸡丁 £7.50。',
        '今天油焖大虾 £9.80。',
      ]},
      { when: c => c.week >= 14 && c.npcRel?.mei >= 5, replies: [
        '今天羊肉锅 冷成这样赶紧来。',
        '今天酸辣土豆丝 学生 £5 你来。',
        '今天炖牛腩 我多炖了一锅 你来。',
        '今天饺子 我儿子放假在帮我包 你来挑刺。',
      ]},
      { when: c => c.week >= 14, replies: [
        '今天羊肉锅 暖身。',
        '今天炖牛腩 £8 学生折扣。',
        '今天饺子 现包 £6 一打。',
      ]},
      { when: c => c.npcRel?.mei >= 5, replies: [
        '今天红烧狮子头 给你多打一勺。',
        '今天番茄牛腩面 你看起来挺累 多加一勺辣酱？',
        '今天卤味拼盘 你来挑。',
      ]},
      // 初识 / 默认
      { replies: [
        '今天红烧狮子头 £6.5。',
        '今天卤味拼盘 £7。',
        '今天炒青菜 £4 加蛋 +£1。',
        '今天番茄牛腩面 £7.5。',
      ]},
    ]),
    effect: {},
  });
  // 「这周怎么样」按 storyProgress / flags 变 —— 姐的家庭近况会变
  opts.push({
    id: 'mei_smalltalk_week', kind: 'smalltalk',
    label: '"姐 这周还好吗"',
    playerText: '姐 你这周还好吗',
    npcReply: pickReply(ctx, [
      { when: c => (c.storyProgress?.mei || 0) >= 3, replies: [
        '老二感冒了 哎 这种天气 没办法。',
        '我妹妹寄来一袋茶叶 改天分你点。',
        '老大数学考试拿了 A* 我跟他爸说不用补习 他不信。',
        '我老公又抱怨我做菜放太多盐 28 年了 这老头。',
        '上礼拜接到一个外卖单 客户写"求带辣酱"我笑了一晚上。',
      ]},
      { when: c => (c.npcRel?.mei || 0) >= 4, replies: [
        '哎 凑合过呗 你呢',
        '客人多 但累。',
        '没事 平常心。你呢',
      ]},
      // 关系一般的兜底
      { replies: [
        '还行 你呢',
        '凑合。你呢',
      ]},
    ]),
    effect: { npc: { mei: 1 } },
  });
  return opts;
}

// ─────────────────────────────────────────────────────────────
// Whitmore · 学术线
// ─────────────────────────────────────────────────────────────
function whitmoreOptions(ctx) {
  const { npcRel, flags, thread, seen, storyProgress = {} } = ctx;
  const rel = npcRel.whitmore || 0;
  const whitProgress = storyProgress.whitmore || 0;
  const opts = [];

  // ─── storyProgress hooks ───
  if (whitProgress >= 3 && isFresh('whit_post_tutorial_followup', seen)) {
    opts.push({
      id: 'whit_post_tutorial_followup', kind: 'ask',
      label: '"Sir — that point in tutorial..."',
      playerText: 'Sir — about my tutorial point on Foucault. Could I develop it for the next essay?',
      npcReply: 'Yes. Push it to 1500 words. Send draft by Friday. I want to see where you take it.',
      effect: { npc: { whitmore: 1 }, academic: 4 },
    });
  }
  if (whitProgress >= 4 && flags.whitmore_coffee && isFresh('whit_post_coffee_journal', seen)) {
    opts.push({
      id: 'whit_post_coffee_journal', kind: 'reply',
      label: '"Yes — sending the journal piece"',
      playerText: "Sir — confirming the 3000-word piece for the journal issue. Sending Friday.",
      npcReply: "Excellent. Don't apologise for ambition in the framing.",
      effect: { npc: { whitmore: 2 }, academic: 6 },
    });
  }
  if (whitProgress >= 5 && flags.oxford_ref && isFresh('whit_post_ref_letter', seen)) {
    opts.push({
      id: 'whit_post_ref_letter', kind: 'reply',
      label: '"Sir — thank you for the letter"',
      playerText: "Sir — I read the letter. I don't know what to say. Thank you.",
      npcReply: "It's accurate. Stop being modest. Submit the application.",
      effect: { npc: { whitmore: 3 }, academic: 4, belonging: 8 },
    });
  }

  if (lastSaid(thread, 'office hour') && isFresh('whit_book_office', seen)) {
    opts.push({
      id: 'whit_book_office', kind: 'reply',
      label: '"Booking Wednesday 4pm"',
      playerText: 'Wednesday 4pm office hour, sir? I have a methodology question.',
      npcReply: 'Yes. Door will be open.',
      effect: { npc: { whitmore: 1 } },
    });
  }
  if (rel >= 3 && isFresh('whit_ask_essay_feedback', seen)) {
    opts.push({
      id: 'whit_ask_essay_feedback', kind: 'ask',
      label: '"Could you read a draft paragraph?"',
      playerText: 'Could I email you a 300-word paragraph for quick feedback?',
      npcReply: 'Yes. Brief, please. I\'ll have notes by Friday.',
      effect: { npc: { whitmore: 1 } },
    });
  }
  if (rel >= 5 && isFresh('whit_ask_phd', seen)) {
    opts.push({
      id: 'whit_ask_phd', kind: 'ask',
      label: '"Have you ever supervised a PhD?"',
      playerText: 'Sir — what does PhD supervision look like under you? Just curious.',
      npcReply: 'Loosely. I read once a fortnight. I push hard but stay out of the way. Why — are you considering?',
      effect: { npc: { whitmore: 1 }, flag: 'whitmore_phd_inquiry' },
    });
  }
  if (rel >= 7 && isFresh('whit_ask_career', seen)) {
    opts.push({
      id: 'whit_ask_career', kind: 'ask',
      label: '"Sir — career advice for a Chinese student?"',
      playerText: 'Sir — for a Chinese international student staying in UK academia, what would you actually advise?',
      npcReply: 'Honest? Don\'t out-British the British. Bring your context — your particular reading of Foucault from Beijing — that\'s what no one else can write. The rest is just craft.',
      effect: { npc: { whitmore: 2 }, belonging: 6 },
    });
  }

  // ─── 兜底 · repeatable，按 weekPhase / rel 轮换 reading list 推荐 ───
  opts.push({
    id: 'whit_smalltalk_reading', kind: 'smalltalk',
    label: '"Anything new on the reading list?"',
    playerText: "Sir — anything new you'd add to the reading list this term?",
    npcReply: pickReply(ctx, [
      { when: c => c.weekPhase === 'dissertation', replies: [
        "Your dissertation list is now self-curated. Read what your argument requires, not what looks impressive.",
        "If you want a methodology challenge: Saidiya Hartman's *Wayward Lives*. Optional but transformative.",
        "Sara Ahmed's *Cultural Politics of Emotion*. Chapter 3 — it might rearrange your conclusion.",
      ]},
      { when: c => c.npcRel?.whitmore >= 6, replies: [
        "Yes — read the Spivak essay I marked in our last meeting. Twice. The second read is where it pays.",
        "Try Saidiya Hartman's *Lose Your Mother*. Off the syllabus. On purpose.",
        "James Baldwin's *No Name in the Street*. Not for the seminar — for you.",
      ]},
      { when: c => c.weekPhase === 'exam', replies: [
        "Nothing new — focus on what's on the exam. You don't need more, you need depth.",
        "Re-read your own essay drafts. Your strongest arguments are in there, buried.",
      ]},
      { replies: [
        "Yes — Saidiya Hartman's *Wayward Lives*. Optional but transformative.",
        "Add Foucault's *Subject and Power* — short, useful.",
        "Edward Said's *Reflections on Exile*. Brief. Painful. Useful.",
      ]},
    ]),
    effect: { npc: { whitmore: 1 }, academic: 1 },
  });
  opts.push({
    id: 'whit_smalltalk_office_hour', kind: 'smalltalk',
    label: '"Office hour this week, sir?"',
    playerText: 'Sir, do you have office hours this Wednesday?',
    npcReply: pickReply(ctx, [
      { when: c => c.weekPhase === 'exam', replies: [
        'Wednesday 4-5pm — but expect a queue. Email me first.',
        'Wednesday cancelled this week, marking. Email instead.',
      ]},
      { when: c => c.weekPhase === 'dissertation', replies: [
        'Wednesday 4-5pm. Bring a one-page outline and the question you actually want answered.',
        'Wednesday is full for dissertations. Slot Friday 11am, 20 minutes, draft only.',
      ]},
      { replies: [
        'Wednesday 4-5pm as usual. Door will be open.',
        'Wednesday 4-5pm. Come on time — last week three of you queued out into the corridor.',
        'Office hour moved to Thursday 2pm this week, term meetings. Sorry.',
      ]},
    ]),
    effect: {},
  });
  return opts;
}

// ─────────────────────────────────────────────────────────────
// Linnan · 同班 / 恋爱线
// ─────────────────────────────────────────────────────────────
function linnanOptions(ctx) {
  const { npcRel, flags, thread, seen } = ctx;
  const rel = npcRel.linnan || 0;
  const opts = [];

  // ─── Proactive ping follow-ups ───
  // linnan_after_argument: "...在吗"
  if (lastSaid(thread, '在吗') && flags.linnan_cold_war && !flags.linnan_argument_resolved &&
      isFresh('linnan_inma_x', seen, 'linnan_inma_reply')) {
    opts.push({
      id: 'linnan_inma_open', group: 'linnan_inma_reply', kind: 'reply',
      label: '"在 我也在等你说话"',
      playerText: '在 我也在等你说话',
      npcReply: '...今晚来你 ensuite 吗 我们坐下说',
      effect: { npc: { linnan: 3 }, flag: 'linnan_argument_resolved', belonging: 10 },
    });
    opts.push({
      id: 'linnan_inma_apology', group: 'linnan_inma_reply', kind: 'reply',
      label: '"对不起 那天我太炸毛"',
      playerText: '对不起 那天我太炸毛 我把焦虑发你身上',
      npcReply: '...我等的就是这句话。今晚来。',
      effect: { npc: { linnan: 5 }, flag: 'linnan_argument_resolved', belonging: 14 },
    });
    opts.push({
      id: 'linnan_inma_silence', group: 'linnan_inma_reply', kind: 'reply',
      label: '（不回）',
      playerText: '（已读不回）',
      npcReply: '（48 小时后）好。明白了。',
      effect: { npc: { linnan: -8 }, belonging: -10, flag: 'linnan_breakup' },
    });
  }
  // linnan_dating_morning: "早 醒了吗 今晚 ensuite 还是图书馆"
  if (lastSaid(thread, '今晚 ensuite 还是') && flags.linnan_dating &&
      isFresh('linnan_morning_x', seen, 'linnan_morning_reply')) {
    opts.push({
      id: 'linnan_morning_ensuite', group: 'linnan_morning_reply', kind: 'reply',
      label: '"ensuite 我做饭"',
      playerText: 'ensuite 我做饭 你来 8 点',
      npcReply: '行。我带 wine. 我妈牌',
      effect: { npc: { linnan: 1 }, belonging: 4 },
    });
    opts.push({
      id: 'linnan_morning_lib', group: 'linnan_morning_reply', kind: 'reply',
      label: '"图书馆 我得 dissertation"',
      playerText: '图书馆 dissertation 写不动',
      npcReply: '行 4F 我抢座 带 chai 给你',
      effect: { npc: { linnan: 1 } },
    });
  }

  if (lastSaid(thread, '笔记') && isFresh('linnan_yes_notes', seen)) {
    opts.push({
      id: 'linnan_yes_notes', kind: 'reply',
      label: '"行 我发你"',
      playerText: '行 我笔记发你 加微信 word 文档',
      npcReply: '靠你这个比 reading list 还系统 😭',
      effect: { npc: { linnan: 2 } },
    });
  }
  if (rel >= 3 && isFresh('linnan_ask_food', seen)) {
    opts.push({
      id: 'linnan_ask_food', kind: 'ask',
      label: '"周末一起 Nando\'s？"',
      playerText: '周末 Nando\'s？Soho 那家',
      npcReply: '行 周五晚 我请 上次你救我笔记的命',
      effect: { npc: { linnan: 1 } },
    });
  }
  if (flags.linnan_dating && isFresh('linnan_dating_morning', seen)) {
    opts.push({
      id: 'linnan_dating_morning', kind: 'ask',
      label: '"早 想吃啥？"',
      playerText: '早。想吃啥？我下楼 Pret 给你带',
      npcReply: 'oat latte 加一片 ham & cheese 谢谢宝[爱心]',
      effect: { npc: { linnan: 1 } },
    });
  }
  // 冷战和好的几种姿态 互斥（道歉 vs 等对方 vs 主动一句但不正式道歉）
  if (flags.linnan_cold_war && !flags.linnan_argument_resolved &&
      isFresh('linnan_cold_war_x', seen, 'linnan_cold_war_makeup')) {
    opts.push({
      id: 'linnan_cold_war_apology', group: 'linnan_cold_war_makeup', kind: 'reply',
      label: '"对不起 那天我炸毛了"',
      playerText: '对不起 那天我炸毛了 是我把焦虑发你身上 这是我的错',
      npcReply: '...嗯。今晚来你 ensuite 吗 我带 Pret',
      effect: { npc: { linnan: 4 }, flag: 'linnan_argument_resolved', belonging: 12 },
    });
    opts.push({
      id: 'linnan_cold_war_soft', group: 'linnan_cold_war_makeup', kind: 'reply',
      label: '"今晚有空吗？"（不直接道歉）',
      playerText: '今晚有空吗',
      npcReply: '...有。你过来。但有些话还是要说清楚。',
      effect: { npc: { linnan: 1 } },
    });
    opts.push({
      id: 'linnan_cold_war_proud', group: 'linnan_cold_war_makeup', kind: 'reply',
      label: '"我也没错啊"（坚持立场）',
      playerText: '我也没错啊 你也得想想自己',
      npcReply: '好。那我们就这样吧。',
      effect: { npc: { linnan: -3 }, belonging: -5 },
    });
  }

  // ─── 兜底 · repeatable，按 dating flag / weekPhase 变化 ───
  opts.push({
    id: 'linnan_smalltalk_lecture', kind: 'smalltalk',
    label: '"今天 lecture 怎么样"',
    playerText: '今天 lecture 怎么样 我没去',
    npcReply: pickReply(ctx, [
      { when: c => c.flags?.linnan_dating && c.weekPhase === 'exam', replies: [
        '考试周哪有 lecture 宝。我图书馆 4F 你来不来',
        '没 lecture 在复习。要不要晚上一起 review',
        '宝你睡了么 别熬',
      ]},
      { when: c => c.flags?.linnan_dating && c.weekPhase === 'dissertation', replies: [
        '宝 dissertation 季哪有 lecture',
        '今天 supervisor meeting 我 30 分钟被退稿 4 次 心态崩',
        '没 lecture 在 4F 写论文 等你来',
      ]},
      { when: c => c.flags?.linnan_dating, replies: [
        '没啥 PDF 截屏给你 宝',
        'tutor 又把 "Foucault" 念成 "Foo-cult" 我笑死',
        '一般 但你那个 reading list 我帮你抄了',
        '宝你为啥没去 是不是没起得来 我 8 点给你电话叫醒下次',
      ]},
      { when: c => c.flags?.linnan_friend_zoned, replies: [
        '没啥 PDF 我截了 你要不要',
        '今天讨论挺尬 全班沉默 30 秒',
        '一般 你呢',
      ]},
      { when: c => c.weekPhase === 'exam', replies: [
        '考试周没 lecture',
        '没课 4F 占座了 你要不要来',
      ]},
      { replies: [
        '没啥 PDF 截屏给你',
        '一般 tutor 念错了 3 个名字',
        '今天讨论挺烂 大家都没读 reading',
      ]},
    ]),
    effect: {},
  });
  opts.push({
    id: 'linnan_smalltalk_food', kind: 'smalltalk',
    label: '"周末吃啥"',
    playerText: '周末有空一起吃饭吗',
    npcReply: pickReply(ctx, [
      { when: c => c.flags?.linnan_dating, replies: [
        '宝 Soho 那家鸡公煲？我请',
        '我做 ensuite 番茄炒蛋 你带 wine',
        '宝想吃 hotpot 吗 翠华还是海底捞',
        'Borough Market 周六？我看到一家小法餐',
        '宝你说吧 我都行 你最近哪里没去过',
      ]},
      { when: c => c.flags?.linnan_friend_zoned, replies: [
        '我周末有点忙 改天',
        '看情况 你想去哪',
        '可以 但带几个人比较自然',
      ]},
      { replies: [
        '有 Soho 那家鸡公煲？',
        '行 Chinatown 那家川菜',
        'Borough Market 周六？',
      ]},
    ]),
    effect: { npc: { linnan: 1 } },
  });
  return opts;
}

// ─────────────────────────────────────────────────────────────
// Mark · 隔壁房 flatmate
// ─────────────────────────────────────────────────────────────
function markOptions(ctx) {
  const { flags, thread, seen, npcRel } = ctx;
  const rel = npcRel.mark || 0;
  const opts = [];

  // 互斥：回应 Mark 的 kitchen 道歉（接受 vs pushback）
  if (lastSaid(thread, 'kitchen') && isFresh('mark_kitchen', seen, 'mark_kitchen_complaint')) {
    opts.push({
      id: 'mark_kitchen_ack', group: 'mark_kitchen_complaint', kind: 'reply',
      label: '"It\'s fine mate — happens"',
      playerText: 'all good mate. happens.',
      npcReply: 'cheers. owe you one. pint at The Crown soon?',
      effect: { npc: { mark: 1 } },
    });
    opts.push({
      id: 'mark_kitchen_pushback', group: 'mark_kitchen_complaint', kind: 'reply',
      label: '"Mate it\'s the third time though"',
      playerText: 'mate honestly it\'s the third time this month',
      npcReply: 'ah. fair. won\'t happen again. seriously.',
      effect: { npc: { mark: 0 } },
    });
  }
  if (rel >= 3 && isFresh('mark_ask_pub', seen)) {
    opts.push({
      id: 'mark_ask_pub', kind: 'ask',
      label: '"Pint at The Crown this week?"',
      playerText: 'pint at The Crown this week mate?',
      npcReply: "YES. tomorrow. 7pm. you're buying first round 🍻",
      effect: { npc: { mark: 2 } },
    });
  }
  if (flags.mark_apologized && isFresh('mark_ask_mum', seen)) {
    opts.push({
      id: 'mark_ask_mum', kind: 'ask',
      label: '"How\'s your mum?"',
      playerText: 'mate how\'s your mum doing? you mentioned she wasn\'t great',
      npcReply: 'better cheers — back on her feet. still telling the church group about her son\'s "Chinese flatmate who taught him to cook". 🙄',
      effect: { npc: { mark: 1 } },
    });
  }

  // ─── 兜底 · repeatable，按 mark 主线 flag / weekPhase 轮换 ───
  opts.push({
    id: 'mark_smalltalk_bin', kind: 'smalltalk',
    label: '"Bin day this week?"',
    playerText: 'mate is it bin day Wednesday or Thursday this week?',
    npcReply: pickReply(ctx, [
      { when: c => c.flags?.mark_friend, replies: [
        'wed black bin. recycling thurs. always mate.',
        'wed black. thurs recycling. council moved it last year and we all panicked.',
        'wed. but the bloke in 3B keeps putting food in recycling. menace.',
        'wed lad. and don\'t use plastic bags, council fined us once.',
      ]},
      { when: c => c.flags?.mark_apologized, replies: [
        'wed black bin. recycling thurs.',
        'wed mate. just stack yours by the gate I\'ll roll it.',
        'wed black thurs recycling. classic.',
      ]},
      { replies: [
        'wed black bin. recycling thurs. always mate.',
        'I think wed. council schedule on the noticeboard.',
        'wed mate. and don\'t leave bags out overnight, foxes.',
      ]},
    ]),
    effect: {},
  });
  opts.push({
    id: 'mark_smalltalk_kitchen', kind: 'smalltalk',
    label: '"You cooking tonight?"',
    playerText: 'you using the kitchen tonight? wanna swap shifts',
    npcReply: pickReply(ctx, [
      { when: c => c.flags?.mark_friend, replies: [
        'free 7-8 then mum\'s on facetime — share the hob mate',
        'frozen pizza job tonight. all yours from 8.',
        'doing pasta again, sorry. teach me something better.',
        'lad — making stir-fry. THE PAN you taught me to save? still alive.',
      ]},
      { when: c => c.flags?.mark_called_out, replies: [
        'free 7-8 mate, I\'ll clean up properly this time.',
        'all yours. trying to be tidy this week.',
      ]},
      { replies: [
        'free 7-8 then mum\'s on facetime — share the hob mate',
        'free tonight. doing toast probably.',
        'after 9 yeah, doing oven chips til then.',
      ]},
    ]),
    effect: {},
  });
  return opts;
}

// ─────────────────────────────────────────────────────────────
// Tom · flatmate · 极简 (他自己没 storyline，只是合租日常)
// ─────────────────────────────────────────────────────────────
function tomOptions(ctx) {
  const { thread, seen, flags } = ctx;
  const opts = [];

  if (lastSaid(thread, 'toast') && isFresh('tom_after_alarm', seen)) {
    opts.push({
      id: 'tom_after_alarm', kind: 'reply',
      label: '"mate next time use the timer"',
      playerText: 'mate next time use the timer please. 100 ppl on the street at 8am',
      npcReply: 'i KNOW. mum bought me a smoke detector mug. apparently this is a personality.',
      effect: {},
    });
  }
  if (flags.burns_night_in && isFresh('tom_burns_followup', seen)) {
    opts.push({
      id: 'tom_burns_followup', kind: 'reply',
      label: '"haggis was actually fine btw"',
      playerText: 'haggis was actually fine you know. confused but tasty',
      npcReply: 'TOLD YOU. mum will be vindicated. burns night next year, you\'re bringing dessert.',
      effect: {},
    });
  }

  // 兜底 · repeatable，按 day / week / weekPhase 轮换吐槽
  opts.push({
    id: 'tom_smalltalk_kitchen', kind: 'smalltalk',
    label: '"kitchen free tonight?"',
    playerText: 'kitchen free 7-8 tonight? cooking',
    npcReply: pickReply(ctx, [
      { when: c => c.weekPhase === 'dissertation', replies: [
        'all yours. I\'m mainlining pot noodle in my room. dissertation = no chewing budget.',
        'free. mark torched a piece of toast at 11am and the alarm went so I\'m never cooking again.',
        'go for it mate. I\'m doing tesco meal deal in bed. mum would weep.',
      ]},
      { when: c => c.weekPhase === 'exam', replies: [
        'free — exams have killed my appetite. I had pop-tarts for dinner. cold.',
        'yours. I\'m revising in there pretending the hob heat is moral support.',
        'all yours. I\'m on coke zero + monster diet til Friday.',
      ]},
      { when: c => c.weekPhase === 'xmas', replies: [
        'free, mum sent me a hamper, eating it in bed til Boxing Day.',
        'mate I\'m off to Manchester Friday, kitchen is YOURS for a week.',
        'free — Christmas dinner was a chicken kiev so I\'m peaking already.',
      ]},
      { when: c => c.day % 5 === 0, replies: [
        'mate I AM cooking — frozen pizza qualifies, fight me.',
        '7:30 onwards. I\'m doing the world\'s saddest stir-fry til then.',
      ]},
      { replies: [
        'all yours. I\'m doing pot noodle in my room. as the gods intended.',
        'free. doing beans on toast at the desk like a true brit.',
        'free mate. mum sent me a curry from home so I\'m sorted.',
        'yours from 7. mark already burned something, alarm is on standby.',
      ]},
    ]),
    effect: {},
  });
  opts.push({
    id: 'tom_smalltalk_pub', kind: 'smalltalk',
    label: '"pint at The Crown later?"',
    playerText: 'pint at the crown later?',
    npcReply: pickReply(ctx, [
      { when: c => c.weekPhase === 'exam', replies: [
        'mate one pint. ONE. I\'ve got revision lined up til midnight, don\'t corrupt me.',
        'after my 2pm I\'m yours. mum says one pint is medicinal.',
      ]},
      { when: c => c.weekPhase === 'dissertation', replies: [
        'no chance lad. word count is 3500 and falling. raincheck.',
        'one pint MAX. dissertation is hostile to fun rn.',
      ]},
      { when: c => c.npcRel?.tom >= 3, replies: [
        'always mate. 7? you\'re buying first round. don\'t pretend you forgot.',
        '8pm yeah? I\'ll save the corner table. Arsenal\'s on.',
        'YES. and a packet of crisps. Tuesday is salt & vinegar law.',
        'mate it\'s been a week. 7pm, lager-shaped therapy.',
      ]},
      { replies: [
        'sure 7pm. you owe me a round from last time.',
        'I\'m good for 8. you sorting the table?',
        'YES. mum says I\'ve been a hermit. proving her wrong.',
      ]},
    ]),
    effect: {},
  });
  opts.push({
    id: 'tom_smalltalk_weather', kind: 'smalltalk',
    label: '"raining again. of course"',
    playerText: 'raining again. of course.',
    npcReply: pickReply(ctx, [
      { when: c => c.week >= 6 && c.week <= 12, replies: [
        'mate it\'s November. the sky has 3 modes: grey, greyer, sideways rain.',
        'this is the bit where mum starts texting me about SAD lamps.',
        'wait til Bonfire Night. rain + fireworks = quintessential british misery.',
      ]},
      { when: c => c.week >= 13 && c.week <= 18, replies: [
        'mate it\'s also dark at 4pm. january is just a long Tuesday.',
        'we get sun in like... March. you\'re doing well to even notice.',
        'this is when mum starts sending me vitamin D adverts.',
      ]},
      { when: c => c.week >= 19 && c.week <= 30, replies: [
        '"April showers" mate, except it\'s May and they haven\'t stopped.',
        'classic british spring — sun for 3 minutes, hailstorm for 15.',
      ]},
      { when: c => c.week >= 31, replies: [
        'wait this is summer? mate this IS summer.',
        '23 degrees and we\'re all on heat-stroke watch. £1 ice-lolly empire about to collapse.',
        'mum just rang to make sure I\'m drinking water. peak british summer alert level.',
      ]},
      { replies: [
        'mate this is what we signed up for. you have an umbrella yet?',
        'don\'t complain — you\'re officially british now if rain offends you.',
        'mate just wait til it\'s drizzling AND sunny. fully cursed weather.',
      ]},
    ]),
    effect: {},
  });
  return opts;
}

// ─────────────────────────────────────────────────────────────
// Priya · Link2Ur Ops Lead · 第一次联系发生在玩家完成 10 单后
// 5 个深度链条：Welcome → Ambassador 邀请 → Equity 谈话 → 合伙人 offer
// ─────────────────────────────────────────────────────────────
function priyaOptions(ctx) {
  const { flags, thread, seen, week, stats = {} } = ctx;
  const completedCount = (ctx.link2urCompletedCount ?? 0);
  const rating = (ctx.link2urRating ?? 5);
  const opts = [];

  // ─── 接 Priya 主动消息（proactive ping 后玩家回复）───
  if (lastSaid(thread, '后台数据') && isFresh('priya_first_reply_x', seen, 'priya_first_reply')) {
    opts.push({
      id: 'priya_first_reply_thanks', group: 'priya_first_reply', kind: 'reply',
      label: '"谢谢 但我没特别 strategic"',
      playerText: '谢谢 但我接单没特别 strategic 看到顺路的就接了',
      npcReply: '正是 — strategic 的人 ROI 死板。你接 18% 亏本单系统标过 7 次"经济不理性"。我们 ops 内部把这种人叫 "high-empathy operator"。下次伦敦 in-person 喝个咖啡？',
      effect: { flag: 'priya_intro_done' },
    });
    opts.push({
      id: 'priya_first_reply_defensive', group: 'priya_first_reply', kind: 'reply',
      label: '"你们看后台干嘛"（防御）',
      playerText: '你们看后台到这种细节干嘛 不是侵犯隐私吗',
      npcReply: '问得对。我们只看 anonymized aggregates。但我每月 review 一遍 top 50 user 的 pattern—— actively flagging "异常友善" 的人。你被 flag 了 7 次。这就是为什么我现在跟你说话。',
      effect: { flag: 'priya_intro_done', npc: { priya: 1 } },
    });
  }

  if (lastSaid(thread, 'in-person 喝个咖啡') && isFresh('priya_coffee_x', seen, 'priya_coffee_reply')) {
    opts.push({
      id: 'priya_coffee_yes', group: 'priya_coffee_reply', kind: 'reply',
      label: '"行 Old Street 周二 4pm？"',
      playerText: '行 Old Street 站附近？周二 4pm 你方便吗',
      npcReply: '周二 4pm，Old Street Allpress Espresso。我穿米色大衣 短发。',
      effect: { flag: 'priya_coffee_scheduled', npc: { priya: 2 } },
    });
    opts.push({
      id: 'priya_coffee_zoom', group: 'priya_coffee_reply', kind: 'reply',
      label: '"我有点紧张 Zoom 行吗"',
      playerText: '说实话我有点紧张 Zoom call 行吗',
      npcReply: '完全可以。我也是社恐 5 年。周二 4pm Zoom 我发链接。穿你舒服的就行。',
      effect: { flag: 'priya_coffee_scheduled', npc: { priya: 1 } },
    });
  }

  // ─── Ambassador 邀请（30 单后）───
  if (lastSaid(thread, 'Ambassador') && isFresh('priya_ambassador_x', seen, 'priya_ambassador_reply')) {
    opts.push({
      id: 'priya_ambassador_yes', group: 'priya_ambassador_reply', kind: 'reply',
      label: '"行 我加入 Ambassador"',
      playerText: '行 那我加入 Ambassador 我能干啥',
      npcReply: '太好了。3 件事：(1) 你 inbox 自动 priority 排在 high-paying clients 前面 (2) 你接 2-3 个学妹 onboarding 抽 15% commission (3) 平台广告 / 校园活动 找你做 face。equity 我们 onboarding 文件里聊。',
      effect: { flag: 'l2u_ambassador_accepted', npc: { priya: 3 }, belonging: 12 },
    });
    opts.push({
      id: 'priya_ambassador_no', group: 'priya_ambassador_reply', kind: 'reply',
      label: '"我想专心毕业 暂时不"',
      playerText: '谢谢但我想专心毕业 这学期 dissertation 太重',
      npcReply: '完全理解 — 学位重要。Offer 留 1 年 你随时回来。',
      effect: { npc: { priya: 1 } },
    });
  }

  // ─── 合伙人 offer（50 单后 · partner arc 触发）───
  if (lastSaid(thread, '合伙人') && isFresh('priya_partner_x', seen, 'priya_partner_reply')) {
    opts.push({
      id: 'priya_partner_yes', group: 'priya_partner_reply', kind: 'reply',
      label: '"我跟你干"',
      playerText: '我跟你干。但是细节文件呢 equity 多少 工资多少',
      npcReply: '4% equity vesting 4 年 + £40k 起步工资 + 你 own "新生互助" 整条产品线。Old Street 那个 office 周一你过来签 NDA。其它合伙人想见你。',
      effect: { flag: 'l2u_partner_accepted', npc: { priya: 5 }, belonging: 25 },
    });
    opts.push({
      id: 'priya_partner_corporate', group: 'priya_partner_reply', kind: 'reply',
      label: '"我考虑去 BCG"',
      playerText: '谢谢 但我考虑 BCG 我父母希望我去咨询',
      npcReply: '理解。咨询是好选择。但是 — 你 BCG 拿到 offer 之后会发现 BCG 不需要你那 18% 亏本单 empathy。我们需要。无论你选哪个 都尊重你。',
      effect: { npc: { priya: 2 } },
    });
    opts.push({
      id: 'priya_partner_freelance', group: 'priya_partner_reply', kind: 'reply',
      label: '"我想自己 freelance"',
      playerText: '谢谢 但是我想试 freelance 自己开个 studio',
      npcReply: '好。如果创业起来缺 PR / 客户 introductions / mentor — ping 我。我们投资了 8 个前 Ambassador 自己创业。',
      effect: { npc: { priya: 2 }, flag: 'priya_blessing_freelance' },
    });
  }

  // ─── 主动联系 ask ───
  if (completedCount >= 5 && isFresh('priya_ask_about_self', seen)) {
    opts.push({
      id: 'priya_ask_about_self', kind: 'ask',
      label: '"你怎么进 Link2Ur 的"',
      playerText: '你之前在哪做 怎么进 Link2Ur 的',
      npcReply: 'Cambridge MBA → PwC 4 年 → 一晚上 4 点写完一份 deck 觉得自己疯了 → 第二天 quit。3 个月后 join Link2Ur founding team。父母现在还以为我在 Big4。',
      effect: { npc: { priya: 1 } },
    });
  }
  if (completedCount >= 8 && isFresh('priya_ask_mission', seen)) {
    opts.push({
      id: 'priya_ask_mission', kind: 'ask',
      label: '"Link2Ur mission 真正是什么"',
      playerText: 'Link2Ur 真正的 mission 是什么 不是 marketing 那套',
      npcReply: '不让任何一个刚下飞机的 international student 觉得 "我没人能问"。我们没法是每个人的 Mei 姐 — 但我们能是 app。',
      effect: { npc: { priya: 2 } },
    });
  }
  if (rating >= 4.7 && completedCount >= 15 && isFresh('priya_ask_advice_career', seen)) {
    opts.push({
      id: 'priya_ask_advice_career', kind: 'ask',
      label: '"我毕业不知道走哪条路"',
      playerText: '说实话我毕业不知道走哪条 freelance / corporate / 创业 / 回国',
      npcReply: '从你后台数据来看 — 你最舒服的是 medium-tier intimate work（不是 mass-scale 也不是 1v1 一对一）。corporate 会让你 burnout 18 个月内。freelance 给你能量但孤独。创业 / Ambassador / 我们这种 hybrid — fits 你 pattern 最好。但 — 这是数据看出来的。你心里答案不一定一样。',
      effect: { npc: { priya: 2 }, flag: 'priya_career_advised' },
    });
  }

  // ─── 兜底 ───
  opts.push({
    id: 'priya_smalltalk_app', kind: 'ask',
    label: '"app 这个 update 多了什么"',
    playerText: 'app 最近 update 多了什么 我没看到 changelog',
    npcReply: 'mostly bug fixes + Mei\'s 在 Chinatown 新签了 partnership。下次 update 会加 vendor 内嵌支付。你想 beta？',
    effect: {},
  });
  opts.push({
    id: 'priya_smalltalk_weather', kind: 'ask',
    label: '"伦敦今天又下雨"',
    playerText: 'lovely weather innit',
    npcReply: 'You\'re getting too British. concerning.',
    effect: { npc: { priya: 1 } },
  });

  return opts;
}

// ─────────────────────────────────────────────────────────────
// 群聊 · 你能 post 进群
// ─────────────────────────────────────────────────────────────
function groupOptions(ctx) {
  const { flags, week, seen, lastGroupMsg, stats = {}, weekPhase } = ctx;
  const opts = [];

  // ─── 群成员说话 → 你可以"接话"回复（kind: 'reply'）───
  // 每个话题给 2-3 个互斥选项 —— group: 'xx_reply' 标记一组，选一个其它消失。
  // 只在 4 天内显示，新群对话出现就自动消失。

  // W2 黄标话题 (xiao_wang 问几点贴黄标)
  if (lastGroupSaid(ctx, '黄标') && isFresh('group_yellow_x', seen, 'group_yellow_reply')) {
    opts.push({
      id: 'group_yellow_helpful', group: 'group_yellow_reply', kind: 'reply',
      label: '回复 · "8:30 之后 但每家不一样"',
      text: '8:30 之后 但每家时间不一样 看店员心情',
      follows: [{ from: 'gou_ge', text: '+1 大学路那家有时候 7:30 就贴' }],
      effect: { belonging: 4 },
    });
    opts.push({
      id: 'group_yellow_joke', group: 'group_yellow_reply', kind: 'reply',
      label: '回复 · "去 5 次就摸清规律了"（吐槽）',
      text: '哥/姐你蹲个 5 次 你就摸清这家阿姨的规律了 别问 经验告诉你',
      follows: [{ from: 'gou_ge', text: '靠 我蹲了 80 次' }],
      effect: { belonging: 2 },
    });
    opts.push({
      id: 'group_yellow_ignore', group: 'group_yellow_reply', kind: 'reply',
      label: '回复 · "买原价不香吗"（劝退）',
      text: '哥/姐 一周才能省 £5 你那个时间 Pret 端盘子都不止',
      follows: [{ from: 'gou_ge', text: '哥/姐你不懂 这是生活方式' }],
      effect: { belonging: -2 },
    });
  }

  // W6 想家 / 名字念错 (xiao_wang)
  if (lastGroupSaid(ctx, '名字') && isFresh('group_name_x', seen, 'group_name_reply')) {
    opts.push({
      id: 'group_name_solidarity', group: 'group_name_reply', kind: 'reply',
      label: '回复 · "我懂 上次 tutor 念我的也念错 3 次"',
      text: '我懂 上次 tutor 念我的也念错了 3 次 后来我直接打断他纠正',
      follows: [
        { from: 'xiao_wang', text: '我也试试 谢谢哥/姐' },
        { from: 'kaize', text: '+1 我去年就这么干的 现在 tutor 念得很标准' },
      ],
      effect: { belonging: 6 },
    });
    opts.push({
      id: 'group_name_english', group: 'group_name_reply', kind: 'reply',
      label: '回复 · "改个英文名吧 我叫 Alex 之后没人念错"',
      text: '改个英文名吧 我之前也想坚持 但后来用 Alex / Emma 之后真的省心',
      follows: [{ from: 'kaize', text: '我也是 改名前 6 个月就一直被念错' }],
      effect: { belonging: 3 },
    });
    opts.push({
      id: 'group_name_dismiss', group: 'group_name_reply', kind: 'reply',
      label: '回复 · "这有什么 适应一下"（凉薄）',
      text: '这有什么 适应一下吧 都来留学了',
      follows: [{ from: 'shang_an', text: '...' }],
      effect: { belonging: -3 },
    });
  }
  if (lastGroupSaid(ctx, '想家') && isFresh('group_homesick_x', seen, 'group_homesick_reply')) {
    opts.push({
      id: 'group_homesick_invite', group: 'group_homesick_reply', kind: 'reply',
      label: '回复 · "周末一起吃顿火锅吧"（主动）',
      text: '周末有空一起吃顿火锅吧 我家锅大 你们来',
      follows: [
        { from: 'xiao_wang', text: '哎呀好啊！哥/姐人真好' },
        { from: 'shang_an', text: '我也来 我带肉' },
      ],
      effect: { belonging: 12, energy: -3, wallet: -25 },
    });
    opts.push({
      id: 'group_homesick_hug', group: 'group_homesick_reply', kind: 'reply',
      label: '回复 · "想家是 normal 的 撑住"（共情）',
      text: '想家是 normal 的 我前两个月每天都想 撑住 会慢慢习惯',
      follows: [{ from: 'xiao_wang', text: '谢谢哥/姐 我再撑撑' }],
      effect: { belonging: 6 },
    });
    opts.push({
      id: 'group_homesick_call', group: 'group_homesick_reply', kind: 'reply',
      label: '回复 · "给你妈打个视频"',
      text: '给你妈打个视频 不用聊正事 就让她看看你在伦敦',
      follows: [{ from: 'shang_an', text: '这建议好 妈也想你' }],
      effect: { belonging: 5 },
    });
  }

  // W8 Bonfire Night
  if (lastGroupSaid(ctx, 'Bonfire') && isFresh('group_bonfire_x', seen, 'group_bonfire_reply')) {
    opts.push({
      id: 'group_bonfire_yes', group: 'group_bonfire_reply', kind: 'reply',
      label: '回复 · "我去！Vauxhall Bridge 见"',
      text: '我去！7:45 Vauxhall Bridge 集合？穿暖点 据说零下',
      follows: [
        { from: 'lily', text: '🎆 提前到 ✨' },
        { from: 'shang_an', text: '可以 我带热可可' },
      ],
      effect: { belonging: 10, energy: -5 },
    });
    opts.push({
      id: 'group_bonfire_park', group: 'group_bonfire_reply', kind: 'reply',
      label: '回复 · "Hyde Park 更便宜 £15 vs Vauxhall 免费"',
      text: '其实 Vauxhall Bridge 免费看烟花视野更好 我不进园 你们呢',
      follows: [{ from: 'gou_ge', text: '靠 你这内行' }],
      effect: { belonging: 6, wallet: -3 },
    });
    opts.push({
      id: 'group_bonfire_skip', group: 'group_bonfire_reply', kind: 'reply',
      label: '回复 · "下次吧 今晚有 deadline"',
      text: '下次吧 今晚有 deadline 你们玩得开心',
      follows: [{ from: 'lily', text: '加油 ddl 战士 ✨' }],
      effect: { belonging: -1, academic: 2 },
    });
  }

  // W10 地铁罢工
  if (lastGroupSaid(ctx, '罢工') && isFresh('group_strike_x', seen, 'group_strike_reply')) {
    opts.push({
      id: 'group_strike_walk', group: 'group_strike_reply', kind: 'reply',
      label: '回复 · "走路 + 公交 提前 2 小时"',
      text: '走路 + 公交 提前 2 小时出门。Citymapper 关掉 tube 看路线',
      follows: [
        { from: 'gou_ge', text: '靠 不知道 Citymapper 能这样' },
        { from: 'kaize', text: '+1 实用' },
      ],
      effect: { belonging: 5 },
    });
    opts.push({
      id: 'group_strike_uber', group: 'group_strike_reply', kind: 'reply',
      label: '回复 · "拼 Uber 吧 5 人摊"',
      text: '拼 Uber 吧 5 个人一辆车摊 £4/人 比 tube 还便宜',
      follows: [{ from: 'lily', text: '我打！我加我朋友 凑 5 个' }],
      effect: { belonging: 4, wallet: -4 },
    });
    opts.push({
      id: 'group_strike_skip', group: 'group_strike_reply', kind: 'reply',
      label: '回复 · "邮件 tutor 请假"',
      text: '邮件 tutor 请假吧 罢工是合法理由 lecture 都会录的',
      follows: [{ from: 'shang_an', text: '+1 别为了打卡硬来' }],
      effect: { belonging: 3, academic: -1 },
    });
  }

  // W13 圣诞节
  if (lastGroupSaid(ctx, '圣诞') && isFresh('group_xmas_x', seen, 'group_xmas_reply')) {
    opts.push({
      id: 'group_xmas_solo', group: 'group_xmas_reply', kind: 'reply',
      label: '回复 · "我没回 一个人在伦敦"',
      text: '我没回 一个人在伦敦 不知道做啥',
      follows: [
        { from: 'lily', text: '宝你别一个人 来我家 我们包饺子' },
        { from: 'shang_an', text: '+1 凑桌 我也没回' },
      ],
      effect: { belonging: 14 },
    });
    opts.push({
      id: 'group_xmas_home', group: 'group_xmas_reply', kind: 'reply',
      label: '回复 · "我回国了 上海见"',
      text: '我刚下飞机 上海见 大家加油在伦敦撑过',
      follows: [{ from: 'gou_ge', text: '羡慕 我留 £3000 机票钱不舍得' }],
      effect: { belonging: 4 },
    });
    opts.push({
      id: 'group_xmas_cotswolds', group: 'group_xmas_reply', kind: 'reply',
      label: '回复 · "我去 flatmate 老家过 Cotswolds"',
      text: '我去 flatmate Sarah 老家 Cotswolds 过 听说她妈做 3 种 stuffing',
      condition: (c) => !!c.flags?.cotswolds_visited,
      follows: [{ from: 'lily', text: '哎呀 ✨ 是去年圣诞那个 cotswolds？' }],
      effect: { belonging: 6 },
    });
  }

  // W18 春节
  if (lastGroupSaid(ctx, '大年三十') && isFresh('group_cny_x', seen, 'group_cny_reply')) {
    opts.push({
      id: 'group_cny_in_london', group: 'group_cny_reply', kind: 'reply',
      label: '回复 · "新年快乐 抢红包"',
      text: '新年快乐 家人们 我也在伦敦 抢红包 抢起来',
      follows: [
        { from: 'gou_ge', text: '红包来了 6 个人手快' },
        { from: 'shang_an', text: '抢到 £0.04 哈哈' },
      ],
      effect: { belonging: 8 },
    });
    opts.push({
      id: 'group_cny_home', group: 'group_cny_reply', kind: 'reply',
      label: '回复 · "我回家了 在和家人吃年夜饭"',
      text: '我回家了 在和家人吃年夜饭 大家在伦敦也好好过',
      follows: [{ from: 'lily', text: '羡慕 ✨ 我没回' }],
      effect: { belonging: 4 },
    });
    opts.push({
      id: 'group_cny_lonely', group: 'group_cny_reply', kind: 'reply',
      label: '回复 · "在 ensuite 一个人 hot pot"',
      text: '在 ensuite 一个人 hot pot 中 这就是我的年夜饭',
      follows: [
        { from: 'gou_ge', text: '哥/姐 加我' },
        { from: 'kaize', text: '凑桌 我有饺子' },
      ],
      effect: { belonging: 10 },
    });
  }

  // W23 英国母亲节
  if (lastGroupSaid(ctx, '母亲节') && isFresh('group_mday_x', seen, 'group_mday_reply')) {
    opts.push({
      id: 'group_mday_called', group: 'group_mday_reply', kind: 'reply',
      label: '回复 · "已给妈打电话 谢谢提醒"',
      text: '已给妈打电话 妈在家激动得不行 谢谢提醒',
      follows: [{ from: 'shang_an', text: '应该的 节日就是借口给妈打电话' }],
      effect: { belonging: 10 },
    });
    opts.push({
      id: 'group_mday_will', group: 'group_mday_reply', kind: 'reply',
      label: '回复 · "晚点打 时差还没到"',
      text: '晚点打 时差还没到 但谢谢提醒',
      follows: [{ from: 'shang_an', text: '记得就好' }],
      effect: { belonging: 4 },
    });
    opts.push({
      id: 'group_mday_skip', group: 'group_mday_reply', kind: 'reply',
      label: '回复 · "中国 5 月那次再打吧"',
      text: '中国母亲节 5 月那次再打吧 这是英国的',
      follows: [{ from: 'shang_an', text: '都打嘛 妈不嫌多' }],
      effect: { belonging: -1 },
    });
  }

  // W31 考试周
  if (lastGroupSaid(ctx, '考不过') && isFresh('group_exam_x', seen, 'group_exam_reply')) {
    opts.push({
      id: 'group_exam_company', group: 'group_exam_reply', kind: 'reply',
      label: '回复 · "撑住 一起 4F 通宵"',
      text: '撑住 我也是 一起 4F 通宵吧 至少有人陪',
      follows: [
        { from: 'xiao_wang', text: '好 你几点到' },
        { from: 'shang_an', text: '凌晨 4 点的 4F 我也常去 我带咖啡' },
      ],
      effect: { belonging: 8, energy: -2 },
    });
    opts.push({
      id: 'group_exam_tips', group: 'group_exam_reply', kind: 'reply',
      label: '回复 · "Past papers 来回 3 遍就够了"',
      text: 'Past papers 来回 3 遍 + 5 篇 model essay 背 framework 就够了 别死磕 reading',
      follows: [
        { from: 'shang_an', text: '+1 这是 hack' },
        { from: 'xiao_wang', text: '保存了 谢谢哥/姐' },
      ],
      effect: { belonging: 5, academic: 1 },
    });
    opts.push({
      id: 'group_exam_pessimist', group: 'group_exam_reply', kind: 'reply',
      label: '回复 · "我也快崩了 别问"',
      text: '我也快崩了 别问 我自己都不知道行不行',
      follows: [{ from: 'gou_ge', text: '一起崩 至少不孤单' }],
      effect: { belonging: 2, energy: -3 },
    });
  }

  // W37 论文季
  if (lastGroupSaid(ctx, '论文季') && isFresh('group_diss_x', seen, 'group_diss_reply')) {
    opts.push({
      id: 'group_diss_starting', group: 'group_diss_reply', kind: 'reply',
      label: '回复 · "刚开始 求 word 模板"',
      text: '我刚开始写 deadline 还远 大家有什么 word 模板分享？',
      follows: [
        { from: 'kaize', text: '我有 SOAS 推荐的 zotero plugin 私你' },
        { from: 'lily', text: '我下载好了再分享 ✨' },
      ],
      effect: { belonging: 4, academic: 1 },
    });
    opts.push({
      id: 'group_diss_done', group: 'group_diss_reply', kind: 'reply',
      label: '回复 · "我已经 5000 字了 你们呢"（凡尔赛）',
      text: '我已经 5000 字了 你们呢 supervisor 说 chapter 2 不错',
      follows: [
        { from: 'gou_ge', text: '靠 凡尔赛 我才 800' },
        { from: 'kaize', text: '哥/姐 牛' },
      ],
      effect: { belonging: -2, academic: 2 },
    });
    opts.push({
      id: 'group_diss_panic', group: 'group_diss_reply', kind: 'reply',
      label: '回复 · "我连 topic 都没定"',
      text: '我连 topic 都没定 supervisor 已经催 2 次了',
      follows: [
        { from: 'shang_an', text: '快定 别拖' },
        { from: 'kaize', text: '我也没定 一起想吧' },
      ],
      effect: { belonging: 4, academic: -1 },
    });
  }

  // W50 论文交了
  if (lastGroupSaid(ctx, '论文交了') && isFresh('group_diss_done_x', seen, 'group_diss_done_reply')) {
    opts.push({
      id: 'group_diss_done_treat', group: 'group_diss_done_reply', kind: 'reply',
      label: '回复 · "刚交完！请大家吃饭"',
      text: '刚交完！请大家吃饭 周六晚 Chinatown？',
      follows: [
        { from: 'gou_ge', text: '哥们 仗义 几点到' },
        { from: 'lily', text: '✨ 我去 ✨' },
        { from: 'shang_an', text: '终于结束了 走起' },
      ],
      effect: { belonging: 14, energy: 5, wallet: -45 },
    });
    opts.push({
      id: 'group_diss_done_solo', group: 'group_diss_done_reply', kind: 'reply',
      label: '回复 · "刚交完！要先睡 36 小时"',
      text: '刚交完！失联 36 小时 醒了再说',
      follows: [{ from: 'gou_ge', text: '懂 我也是' }],
      effect: { belonging: 4, energy: 8 },
    });
    opts.push({
      id: 'group_diss_done_late', group: 'group_diss_done_reply', kind: 'reply',
      label: '回复 · "我还没交 deadline 是后天"',
      text: '我还没交 deadline 后天 你们先 celebrate 我快了',
      follows: [
        { from: 'gou_ge', text: '快 deadline 战士' },
        { from: 'shang_an', text: '撑住 你能行' },
      ],
      effect: { belonging: 4, academic: -1 },
    });
  }

  // 反诈话题：群里有人聊到诈骗 → 你可以警告
  if (lastGroupMsg && /大使馆|护照|转账|洗钱|急转/.test(lastGroupMsg.text || '')) {
    if (isFresh('group_warn_consul', seen)) {
      opts.push({
        id: 'group_warn_consul', kind: 'post',
        label: 'POST · 警告"是骗子 别转！"',
        text: '是骗子！大使馆从来不打电话要钱！立刻挂掉 + block。任何"转钱解冻"都是 scam！',
        follows: [
          { from: 'gou_ge', text: '+1 兄弟说得对' },
          { from: 'lily', text: '宝宝你这条置顶谢谢 ✨' },
          { from: 'shang_an', text: '我备忘录截图了 谢谢' },
        ],
        effect: { flag: 'scam_educator', belonging: 8 },
      });
    }
  }

  if (week >= 4 && isFresh('group_intro', seen)) {
    opts.push({
      id: 'group_intro', kind: 'post',
      label: 'POST · 自我介绍 + 求 Pret 优惠码',
      text: '大家好 我刚来 SOAS MSc 求一个 Pret 学生折扣码 + 哪里能买便宜被子',
      follows: [
        { from: 'gou_ge', text: 'Pret app 注册 student verify 直接 5%' },
        { from: 'lily', text: 'Argos 被子 £15 别买 IKEA' },
        { from: 'kaize', text: '欢迎欢迎 群里都是兄弟姐妹' },
      ],
      effect: { belonging: 5, flag: 'cssa_intro_done' },
    });
  }

  if (week >= 8 && isFresh('group_ask_landlord', seen)) {
    opts.push({
      id: 'group_ask_landlord', kind: 'post',
      label: 'POST · "找房子大家有靠谱平台吗"',
      text: '家人们 ensuite 9 月到期 看了 Gumtree 全是骗子 大家用什么靠谱',
      follows: [
        { from: 'shang_an', text: 'SpareRoom 比 Gumtree 安全。Foxtons 中介贵但有 reference check。' },
        { from: 'gou_ge', text: 'Gumtree 全是骗子 我朋友被骗 £400 押金' },
        { from: 'kaize', text: '我们二居有空房 想合租可以私聊' },
      ],
      effect: { belonging: 4 },
    });
  }

  if (week >= 16 && isFresh('group_ask_dissertation', seen)) {
    opts.push({
      id: 'group_ask_dissertation', kind: 'post',
      label: 'POST · "dissertation 大家进度怎样"',
      text: '家人们 dissertation 大家进度怎么样 我才 4500 字 我心态有点崩',
      follows: [
        { from: 'shang_an', text: '4500 字到 W16 是正常的别慌' },
        { from: 'gou_ge', text: '我才 2800 😅 你比我健康' },
        { from: 'lily', text: '宝宝加油 ✨ 我每天 200 字' },
        { from: 'qian_shui', text: '（出现）量化计划 + 强制每天 ×60min Pomodoro 真的有效' },
      ],
      effect: { belonging: 6 },
    });
  }

  if (week >= 30 && (flags.scam_pig_resisted || flags.scam_consul_resisted ||
      flags.scam_psw_resisted || flags.scam_sponsor_resisted) &&
      isFresh('group_share_resist_story', seen)) {
    opts.push({
      id: 'group_share_resist_story', kind: 'post',
      label: 'POST · 分享自己抗住 scam 的经历',
      text: '兄弟姐妹 之前抗住一波杀猪盘 / 假大使馆 / 假 sponsor 写一下避免新生踩坑 ↓ (1500 字)',
      follows: [
        { from: 'shang_an', text: '建议群主置顶' },
        { from: 'lily', text: '太勇了 ✨' },
        { from: 'gou_ge', text: '兄弟我也保存了 转给我表妹' },
        { from: 'xiao_wang', text: '我前天差点被骗 看完这条 block 了 谢谢学长' },
      ],
      effect: { flag: 'scam_educator', belonging: 14, academic: 2 },
    });
  }

  // weekPhase 感知 · 大家在同步阶段会聊不同话题
  if (weekPhase === 'exam' && isFresh('group_exam_solidarity', seen)) {
    opts.push({
      id: 'group_exam_solidarity', kind: 'post',
      label: 'POST · "考完一个 还有两个"',
      text: '兄弟姐妹 我刚考完一个 还有两个 大家加油 凌晨 4 点的图书馆我看到几个 hi',
      follows: [
        { from: 'gou_ge', text: '我也凌晨 4 点 我看到一个长得像你的 应该是你' },
        { from: 'shang_an', text: '考完一个就吃顿好的 别熬到 6 点' },
        { from: 'lily', text: '宝宝撑住 ✨ 考完去 brunch' },
        { from: 'kaize', text: '8AM 9AM 10AM 各种时段图书馆里都有人崩' },
      ],
      effect: { belonging: 8 },
    });
  }
  if (weekPhase === 'dissertation' && week >= 45 && isFresh('group_diss_endgame', seen)) {
    opts.push({
      id: 'group_diss_endgame', kind: 'post',
      label: 'POST · "deadline 5 天 我崩了"',
      text: 'deadline 5 天 还差 6000 字 我现在在 ensuite 想哭',
      follows: [
        { from: 'shang_an', text: '5 天 6000 字 = 1200/天 是 doable 的。坐下。打开 word。开始写。其它后说。' },
        { from: 'gou_ge', text: '兄弟我去年也这状态 最后 24 小时写了 3500 字 你能行' },
        { from: 'lily', text: '宝宝 ddl 战士 ✨ 你交完我请你 brunch' },
      ],
      effect: { belonging: 10, energy: 3 },
    });
  }
  if (weekPhase === 'xmas' && isFresh('group_xmas_solo', seen)) {
    opts.push({
      id: 'group_xmas_solo', kind: 'post',
      label: 'POST · "今年没回国 + 谁还在伦敦"',
      text: '家人们 今年没回国 + 谁还留在伦敦 凑桌吃年夜饭吗 包饺子',
      follows: [
        { from: 'kaize', text: '我！我家小公寓挺大 周日来我家' },
        { from: 'lily', text: '宝宝我也没回 ✨ 我带 wine 来' },
        { from: 'gou_ge', text: '我也来 我带饺子皮 + 春晚直播链接' },
        { from: 'xiao_wang', text: '同学 我能去吗 我刚来不熟人' },
      ],
      effect: { belonging: 18, flag: 'cssa_xmas_dinner' },
    });
  }

  // 状态 hooks
  if (stats && stats.belonging <= 18 && isFresh('group_vent_lonely', seen)) {
    opts.push({
      id: 'group_vent_lonely', kind: 'post',
      label: 'POST · "今天有点 down"',
      text: '家人们 今天有点 down 没啥事 就想说一下',
      follows: [
        { from: 'shang_an', text: '宝 你不孤独。要不要约 zoom 聊一下？' },
        { from: 'lily', text: 'mwah 抱抱 ✨ 想吃啥外卖姐请你' },
        { from: 'kaize', text: '兄弟姐妹 撑一下 我们都在' },
      ],
      effect: { belonging: 10 },
    });
  }

  // 兜底
  opts.push({
    id: 'group_smalltalk_weather', kind: 'post',
    label: 'POST · 吐槽伦敦天气',
    text: '靠 伦敦今天又下雨 我没带伞 全淋湿了',
    follows: [
      { from: 'gou_ge', text: 'mate 这就是伦敦' },
      { from: 'lily', text: '宝宝 Met Office app 装一下 ✨' },
    ],
    effect: {},
  });
  opts.push({
    id: 'group_smalltalk_yellow', kind: 'post',
    label: 'POST · "黄标几点"（找狗哥）',
    text: '家人们 我家附近 Tesco 几点贴黄标 求情报',
    follows: [
      { from: 'gou_ge', text: '8:30 之后 你别问 我去过 100 次' },
      { from: 'shang_an', text: '别老抢黄标 自己做饭便宜健康' },
    ],
    effect: {},
  });
  opts.push({
    id: 'group_smalltalk_food', kind: 'post',
    label: 'POST · "Soho 哪家中餐好吃"',
    text: '问下 Soho 这边性价比高的中餐 别推荐 Wagamama',
    follows: [
      { from: 'lily', text: '金龙轩 / Mei\'s Lucky Star 都不错 ✨' },
      { from: 'kaize', text: 'Mei 姐家 良心价 老板娘人也好' },
    ],
    effect: {},
  });

  return opts;
}

// ─────────────────────────────────────────────────────────────
// Public dispatch
// ─────────────────────────────────────────────────────────────
const NPC_OPTION_FNS = {
  sarah:    sarahOptions,
  aditi:    aditiOptions,
  wangkai:  wangkaiOptions,
  mei:      meiOptions,
  whitmore: whitmoreOptions,
  linnan:   linnanOptions,
  mark:     markOptions,
  tom:      tomOptions,
  mom:      momOptions,
  priya:    priyaOptions,
};

// 按 (day + npcId + opt.id) 稳定 hash 从池里挑 N 个 —— 同一天打开同样一组，跨天换。
function pickDailyN(pool, n, day, npcId) {
  if (pool.length <= n) return pool;
  const seed = (day || 1) * 31 + (npcId ? npcId.charCodeAt(0) : 0);
  const decorated = pool.map((opt) => {
    let h = seed;
    for (let i = 0; i < opt.id.length; i++) h = (h * 33 + opt.id.charCodeAt(i)) >>> 0;
    return { opt, hash: h };
  });
  decorated.sort((a, b) => a.hash - b.hash);
  return decorated.slice(0, n).map(d => d.opt);
}

export function getChatOptions(npcId, ctx) {
  const fn = NPC_OPTION_FNS[npcId];
  if (!fn) return [];

  const all = fn(ctx);
  // 一次性过滤：requires 链 + 已永久 seen + 今日已问过
  const seen = ctx.seen || [];
  const seenToday = ctx.seenToday || [];
  let filtered = all.filter(o =>
    meetsPrereq(o.requires, seen) && !seenToday.includes(o.id),
  );

  // 分桶：
  // · alwaysShow = reply / 带 flag effect / 带 requires 链 / 携带 group（剧情节点）
  //               —— 这些每次都该显示
  // · ask        = 普通 ask（无 flag/无 requires）—— 每日随机 2 个
  // · smalltalk  = kind 'smalltalk' —— 每日随机 2 个
  const alwaysShow = filtered.filter(o =>
    o.kind === 'reply' ||
    (o.effect && o.effect.flag) ||
    (o.requires && o.requires.length) ||
    o.group,
  );
  const dailyAskPool = filtered.filter(o =>
    o.kind === 'ask' && !o.requires?.length && !(o.effect && o.effect.flag) && !o.group,
  );
  const smalltalkPool = filtered.filter(o => o.kind === 'smalltalk');

  // === 剧情情境下隐藏闲聊噪音 ===
  // 有 reply（接 NPC 上一句话）或 flag-effect 节点 → 玩家应该专注，不要冒出
  // 无关的"How was lecture / pancake day" 之类 smalltalk + 普通 ask。
  const hasContextReply = alwaysShow.some(o =>
    o.kind === 'reply' || (o.effect && o.effect.flag),
  );

  alwaysShow.sort((a, b) => optionPriority(b) - optionPriority(a));

  if (hasContextReply) {
    // 只显示剧情 / 回复 / 深度链选项；闲聊和普通日常 ask 暂时让位
    return alwaysShow.slice(0, 5);
  }

  const dailyAsk = pickDailyN(dailyAskPool, 2, ctx.day, npcId);
  const dailyChat = pickDailyN(smalltalkPool, 2, ctx.day, npcId);
  return [...alwaysShow.slice(0, 3), ...dailyAsk, ...dailyChat];
}

export function getGroupOptions(ctx) {
  const all = groupOptions(ctx);
  const seen = ctx.seen || [];
  // 群聊每条 post 都是一次性 —— 选过就不再显示
  const filtered = all.filter(o =>
    meetsPrereq(o.requires, seen) && !seen.includes(o.id),
  );
  filtered.sort((a, b) => optionPriority(b) - optionPriority(a));
  return filtered.slice(0, 5);
}
