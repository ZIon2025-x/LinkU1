// NPC 主动找玩家系统。
//
// 每天 endDay 时引擎扫描所有 hook —— 任一 condition 满足且 id 没在
// seenProactiveHooks 中就触发：通过 addMessage 推一条 NPC 文字到对应
// thread，同时打 unread badge。
//
// 设计原则:
//   1. 主动消息要 reactive 到玩家最近发生的事（剧情完成/状态低落/久未联系）
//   2. 不要 spam —— 每个 NPC 每周触发不超过 1-2 次
//   3. NPC 个性要保留 —— Sarah 用英语 / Mei 中文 / Whitmore 正式
//
// hook 形状:
//   {
//     id: 'sarah_proactive_after_cotswolds',
//     npcId: 'sarah',
//     fromName: 'Sarah',
//     condition: (state) => bool,
//     text: 'mum sent me asking about you 😂 ...',
//     priority: 1,                       // 数字越大越优先
//   }

import { CHAT_NPC_META } from './chatTopics.js';

// helper: 检查 thread 里 NPC 上次发消息距今多少天
const daysSinceLastNpc = (thread, currentDay) => {
  if (!thread || !thread.length) return 999;
  const themMsgs = thread.filter(m => m.role === 'them');
  if (!themMsgs.length) return 999;
  const last = themMsgs[themMsgs.length - 1];
  return Math.max(0, currentDay - (last.day || 0));
};

// helper: 检查玩家上次回复距今多少天 (0 = 玩家从没回过)
const daysSincePlayerReply = (thread, currentDay) => {
  if (!thread || !thread.length) return 999;
  const youMsgs = thread.filter(m => m.role === 'you');
  if (!youMsgs.length) return 999;
  const last = youMsgs[youMsgs.length - 1];
  return Math.max(0, currentDay - (last.day || 0));
};

const sp = (state, npc) => (state.storyProgress || {})[npc] || 0;
const rel = (state, npc) => (state.npcRel || {})[npc] || 0;
const flag = (state, key) => !!(state.flags || {})[key];

export const PROACTIVE_CHAT_HOOKS = [
  // ─────────────────────────────────────────────────────────────
  // SARAH · 周末 mum 转述 / 烂醉拉你 / 邀新尝试
  // ─────────────────────────────────────────────────────────────
  {
    id: 'sarah_post_cotswolds_mum',
    npcId: 'sarah', fromName: 'Sarah',
    condition: (s) => flag(s, 'cotswolds_visited') && Math.ceil(s.day / 7) >= 16,
    text: "btw mum keeps asking when 'that lovely friend' is coming back. she has a list of plants she wants to give you.",
    priority: 2,
  },
  {
    id: 'sarah_check_in_silence',
    npcId: 'sarah', fromName: 'Sarah',
    condition: (s) => rel(s, 'sarah') >= 4 &&
      daysSincePlayerReply(s.chatThreads?.sarah, s.day) >= 5,
    text: 'oi. you alive? 5 days no reply, this isn\'t like you.',
    priority: 3,
  },
  {
    id: 'sarah_pancake_remind',
    npcId: 'sarah', fromName: 'Sarah',
    condition: (s) => Math.ceil(s.day / 7) === 21 && rel(s, 'sarah') >= 3,
    text: "PANCAKE DAY tomorrow!! kitchen 7pm. I have lemon. you have... whatever you have 🥞",
    priority: 2,
  },
  {
    id: 'sarah_after_essay_drama',
    npcId: 'sarah', fromName: 'Sarah',
    condition: (s) => sp(s, 'sarah') >= 2 && rel(s, 'sarah') >= 4,
    text: "thanks for last week btw. you're the only person who reads my drafts properly. wine soon?",
    priority: 1,
  },
  {
    id: 'sarah_xmas_remind',
    npcId: 'sarah', fromName: 'Sarah',
    condition: (s) => Math.ceil(s.day / 7) === 13 && rel(s, 'sarah') >= 5,
    text: "Cotswolds Christmas — yes/no? mum needs the headcount for stuffing. seriously.",
    priority: 3,
  },

  // ─────────────────────────────────────────────────────────────
  // MOM · 持续低 belonging / 每月底 / 节日前 / 你完成里程碑
  // ─────────────────────────────────────────────────────────────
  {
    id: 'mom_low_belonging_check',
    npcId: 'mom', fromName: '🇨🇳 妈妈',
    condition: (s) => (s.stats?.belonging ?? 50) <= 20 &&
      daysSinceLastNpc(s.chatThreads?.mom, s.day) >= 4,
    text: '傻孩子 妈这边老是想你。给妈打个电话呗',
    priority: 4,
  },
  {
    id: 'mom_monthly_stipend',
    npcId: 'mom', fromName: '🇨🇳 妈妈',
    condition: (s) => s.day % 30 === 0 && s.day > 0,
    text: '这个月生活费已经转了 £700 收一下 别舍不得吃',
    priority: 2,
  },
  {
    id: 'mom_pre_xmas_concern',
    npcId: 'mom', fromName: '🇨🇳 妈妈',
    condition: (s) => Math.ceil(s.day / 7) === 12,
    text: '马上圣诞节了 你今年不回 妈给你包了点饺子寄过去 (虽然到的时候肯定不能吃了)',
    priority: 3,
  },
  {
    id: 'mom_after_brp',
    npcId: 'mom', fromName: '🇨🇳 妈妈',
    condition: (s) => flag(s, 'brp_collected') && !flag(s, 'mom_brp_proactive'),
    // mom 不认识伦敦的人，所以改成她猜出来 / 看学校官方邮件这种合理来源
    text: '妈看学校发的邮件 你 BRP 早就到了吧 你倒是不告诉妈一声 哎',
    priority: 3,
  },
  {
    id: 'mom_after_first_essay',
    npcId: 'mom', fromName: '🇨🇳 妈妈',
    condition: (s) => Math.ceil(s.day / 7) >= 12 && Math.ceil(s.day / 7) <= 14,
    text: '第一个 essay 交了吗 妈不懂你写啥 但是你交了告诉妈一声',
    priority: 2,
  },
  {
    id: 'mom_after_dissertation_topic',
    npcId: 'mom', fromName: '🇨🇳 妈妈',
    condition: (s) => Math.ceil(s.day / 7) >= 38 && !!s.dissertationTopic,
    text: '论文题目定了吗 妈跟你爸说 你写啥都行 妈给你存一份',
    priority: 2,
  },
  {
    id: 'mom_visit_followup',
    npcId: 'mom', fromName: '🇨🇳 妈妈',
    condition: (s) => flag(s, 'parents_invited') &&
      Math.ceil(s.day / 7) >= 32 &&
      !flag(s, 'mom_visit_booked'),
    text: '妈跟你爸商量了 4 月签证可以搞 你给我们一个时间表 我们订机票',
    priority: 4,
  },

  // ─────────────────────────────────────────────────────────────
  // ADITI · 完成共同事件后的延续 / 久未联系
  // ─────────────────────────────────────────────────────────────
  {
    id: 'aditi_after_essay_swap',
    npcId: 'aditi', fromName: 'Aditi',
    condition: (s) => flag(s, 'aditi_essay_swap') &&
      daysSinceLastNpc(s.chatThreads?.aditi, s.day) >= 3,
    text: 'btw — your draft made me rewrite my whole intro. owe you a chai. tomorrow 4F?',
    priority: 2,
  },
  {
    id: 'aditi_dad_update',
    npcId: 'aditi', fromName: 'Aditi',
    condition: (s) => sp(s, 'aditi') >= 3 && Math.ceil(s.day / 7) >= 26,
    text: 'thought you should know — dad\'s ok this week. your message helped more than you know 💜',
    priority: 3,
  },
  {
    id: 'aditi_late_check_in',
    npcId: 'aditi', fromName: 'Aditi',
    condition: (s) => rel(s, 'aditi') >= 5 &&
      daysSincePlayerReply(s.chatThreads?.aditi, s.day) >= 6,
    text: "haven't heard from you in a week. library 4F tomorrow? I'll save the corner.",
    priority: 3,
  },
  {
    id: 'aditi_diwali_proactive',
    npcId: 'aditi', fromName: 'Aditi',
    condition: (s) => Math.ceil(s.day / 7) === 8 && rel(s, 'aditi') >= 3,
    text: "Diwali this Friday — small thing at mine. just sweets and lights. you in? 🪔",
    priority: 3,
  },

  // ─────────────────────────────────────────────────────────────
  // WANGKAI · 业务节点 / 求救
  // ─────────────────────────────────────────────────────────────
  {
    id: 'wk_business_open',
    npcId: 'wangkai', fromName: '王凯学长',
    condition: (s) => flag(s, 'wangkai_business') && !flag(s, 'wk_first_paycheck'),
    text: '哥们 我上周开张第一周 算了下 净赚 £820 你那 10% 等下转你',
    priority: 3,
  },
  {
    id: 'wk_late_help',
    npcId: 'wangkai', fromName: '王凯学长',
    condition: (s) => flag(s, 'wangkai_business') && rel(s, 'wangkai') >= 4 &&
      Math.ceil(s.day / 7) >= 25 && (s.day % 14 === 5),
    text: '哥们 今晚 9 点店里出单爆了 来帮忙吗 一晚 £30 + 免费奶茶',
    priority: 2,
  },
  {
    id: 'wk_referral_followup',
    npcId: 'wangkai', fromName: '王凯学长',
    condition: (s) => flag(s, 'wangkai_referral') &&
      daysSincePlayerReply(s.chatThreads?.wangkai, s.day) >= 4,
    text: '哥 我表哥那边面试咋样 别给我丢人',
    priority: 3,
  },

  // ─────────────────────────────────────────────────────────────
  // MEI · 季节关怀 / 发现你瘦
  // ─────────────────────────────────────────────────────────────
  {
    id: 'mei_winter_concern',
    npcId: 'mei', fromName: 'Mei 姐',
    condition: (s) => Math.ceil(s.day / 7) >= 14 && Math.ceil(s.day / 7) <= 17 && rel(s, 'mei') >= 3,
    text: '伦敦冷得不像话 你穿暖了吗 周末来店里 姐做羊肉锅子',
    priority: 2,
  },
  {
    id: 'mei_low_energy_concern',
    npcId: 'mei', fromName: 'Mei 姐',
    condition: (s) => (s.stats?.energy ?? 50) <= 25 && rel(s, 'mei') >= 4,
    text: '傻孩子 你最近脸色不好 来吃饭 姐给你煮粥',
    priority: 3,
  },
  {
    id: 'mei_pre_xmas',
    npcId: 'mei', fromName: 'Mei 姐',
    condition: (s) => Math.ceil(s.day / 7) === 13 && rel(s, 'mei') >= 4,
    text: '今年圣诞 你回不回国？没回的话来店里 我老公做的福建年菜',
    priority: 3,
  },

  // ─────────────────────────────────────────────────────────────
  // WHITMORE · essay 反馈后 / 推荐信邀请
  // ─────────────────────────────────────────────────────────────
  {
    id: 'whit_after_first_essay',
    npcId: 'whitmore', fromName: 'Prof. Whitmore',
    condition: (s) => Math.ceil(s.day / 7) >= 14 && rel(s, 'whitmore') >= 3 &&
      !flag(s, 'whit_first_essay_followup'),
    text: 'Your essay is back on Moodle. Some thoughts in margin. Would benefit from a 15-minute chat — Wednesday 4pm if you can.',
    priority: 3,
  },
  {
    id: 'whit_dissertation_supervisor',
    npcId: 'whitmore', fromName: 'Prof. Whitmore',
    condition: (s) => Math.ceil(s.day / 7) >= 36 && rel(s, 'whitmore') >= 5,
    text: 'I\'ll be away conference 2-9 May — please send me anything you want feedback on by April 28. Otherwise, week 16 it is.',
    priority: 2,
  },
  {
    id: 'whit_phd_offer',
    npcId: 'whitmore', fromName: 'Prof. Whitmore',
    condition: (s) => sp(s, 'whitmore') >= 5 && rel(s, 'whitmore') >= 7,
    text: 'On the chance you\'re considering a PhD — Oxford applications close 5 December. I\'d be willing to write. Think about it.',
    priority: 4,
  },

  // ─────────────────────────────────────────────────────────────
  // LINNAN · 恋爱期 / 吵架后
  // ─────────────────────────────────────────────────────────────
  {
    id: 'linnan_dating_morning',
    npcId: 'linnan', fromName: '林可儿 / 林楠',
    condition: (s) => flag(s, 'linnan_dating') &&
      daysSinceLastNpc(s.chatThreads?.linnan, s.day) >= 2,
    text: '早 醒了吗 今晚 ensuite 还是图书馆',
    priority: 2,
  },
  {
    id: 'linnan_after_argument',
    npcId: 'linnan', fromName: '林可儿 / 林楠',
    condition: (s) => flag(s, 'linnan_cold_war') && !flag(s, 'linnan_argument_resolved') &&
      daysSinceLastNpc(s.chatThreads?.linnan, s.day) >= 2,
    text: '...在吗',
    priority: 4,
  },
  {
    id: 'linnan_pre_dissertation',
    npcId: 'linnan', fromName: '林可儿 / 林楠',
    condition: (s) => flag(s, 'linnan_dating') && Math.ceil(s.day / 7) === 38,
    text: '我俩这周末 dissertation 一起在图书馆？我带 chai',
    priority: 2,
  },

  // ─────────────────────────────────────────────────────────────
  // MARK · apologized 后 / 不会主动太多
  // ─────────────────────────────────────────────────────────────
  {
    id: 'mark_post_apology_check',
    npcId: 'mark', fromName: 'Mark',
    condition: (s) => flag(s, 'mark_apologized') &&
      daysSinceLastNpc(s.chatThreads?.mark, s.day) >= 7,
    text: 'mate. pint at The Crown this week? on me. owe you one.',
    priority: 2,
  },
  {
    id: 'mark_mum_message',
    npcId: 'mark', fromName: 'Mark',
    condition: (s) => flag(s, 'mark_apologized') && Math.ceil(s.day / 7) >= 30,
    text: 'mate — mum told me to tell you she still has the recipe you wrote out. she\'s going to find you in person to thank.',
    priority: 1,
  },

  // ─────────────────────────────────────────────────────────────
  // 状态低 / 玩家被骗后 → 关键 NPC 主动联系
  // ─────────────────────────────────────────────────────────────
  {
    id: 'sarah_post_scam_intuition',
    npcId: 'sarah', fromName: 'Sarah',
    condition: (s) => (flag(s, 'scammed_pig_full') || flag(s, 'scammed_trading_full')) &&
      !flag(s, 'sarah_knows_scam') &&
      daysSinceLastNpc(s.chatThreads?.sarah, s.day) >= 2,
    text: "babe. I don't want to be that flatmate but you've been off. tea. tonight. no pressure.",
    priority: 5,
  },
  {
    id: 'mei_post_scam_intuition',
    npcId: 'mei', fromName: 'Mei 姐',
    condition: (s) => (flag(s, 'scammed_pig_full') || flag(s, 'scammed_trading_full')) &&
      !flag(s, 'mei_knows_scam') && rel(s, 'mei') >= 5,
    text: '傻孩子 你三天没来吃饭。今天来店里 姐做你最爱的红烧肉',
    priority: 5,
  },

  // ─────────────────────────────────────────────────────────────
  // PRIYA · Link2Ur Ops · 按完成单数 + 评分 阶梯主动联系
  // ─────────────────────────────────────────────────────────────
  // 10 单 → 首次自我介绍 / 邀请认识
  {
    id: 'priya_intro_after_10',
    npcId: 'priya', fromName: 'Priya · Link2Ur',
    condition: (s) => (s.link2urCompleted?.length || 0) >= 10 && !flag(s, 'priya_intro_done'),
    text: 'Hi 我是 Priya 跟你介绍一下 — 我管 Link2Ur 中国区 ops。后台数据看你这段时间 active 前 5% — 想跟你聊一下。不是 sales 也不是 marketing，就是好奇。',
    priority: 4,
  },
  // 20 单 + rating ≥ 4.7 → 关心 + 简单建议
  {
    id: 'priya_check_after_20',
    npcId: 'priya', fromName: 'Priya · Link2Ur',
    condition: (s) => (s.link2urCompleted?.length || 0) >= 20 &&
      (s.link2urRating ?? 5) >= 4.7 && flag(s, 'priya_intro_done') &&
      !flag(s, 'priya_checked_20'),
    text: '你又过了 10 单。注意：你的客单价被低估了。下次申请 high-tier 任务可以加 20%，客户对 4.7 评分 + 20 单的 helper 很认。',
    priority: 3,
    flag: 'priya_checked_20',
  },
  // 30 单 → Ambassador 邀请
  {
    id: 'priya_ambassador_invite_after_30',
    npcId: 'priya', fromName: 'Priya · Link2Ur',
    condition: (s) => (s.link2urCompleted?.length || 0) >= 30 &&
      (s.link2urRating ?? 5) >= 4.8 && !flag(s, 'l2u_ambassador_accepted') &&
      !flag(s, 'priya_ambassador_offered'),
    text: '正式 invite：我们想让你加入 Link2Ur Ambassador 项目。前 0.5% top user 才有的资格。equity 谈话 + onboarding 学妹 + 优先 inbox。你想了解吗？',
    priority: 5,
    flag: 'priya_ambassador_offered',
  },
  // 50 单 + Ambassador → 合伙人 offer
  {
    id: 'priya_partner_offer_after_50',
    npcId: 'priya', fromName: 'Priya · Link2Ur',
    condition: (s) => (s.link2urCompleted?.length || 0) >= 50 &&
      flag(s, 'l2u_ambassador_accepted') &&
      !flag(s, 'l2u_partner_offered'),
    text: '正式谈话：CEO + 其它 5 位合伙人想见你。我们正在 expand founding team — 还差一个 face for 留学生 community。你愿意当我们 #03 合伙人 吗？',
    priority: 5,
    flag: 'l2u_partner_offered',
  },

  // 玩家走 freelance 路 → Priya 旁观致敬
  {
    id: 'priya_acknowledges_freelance',
    npcId: 'priya', fromName: 'Priya · Link2Ur',
    condition: (s) => flag(s, 'freelance_premium') &&
      !flag(s, 'priya_acknowledged_freelance'),
    text: '看到你 LinkedIn 加了 "freelance designer" — 恭喜。如果你需要 startup 客户 introductions 或者 PR — ping 我。Link2Ur 投资了 8 个前 user 的创业 你也是 candidate。',
    priority: 3,
    flag: 'priya_acknowledged_freelance',
  },

  // 玩家 stress 极高 → Priya 直接关心 (非 sales)
  {
    id: 'priya_stress_check',
    npcId: 'priya', fromName: 'Priya · Link2Ur',
    condition: (s) => (s.stress ?? 25) >= 75 &&
      (s.link2urCompleted?.length || 0) >= 5 &&
      !flag(s, 'priya_stress_checked'),
    text: '后台 flag 你压力指数 75+。这条不是 ops 发的 — 是个人发的。先放 app — 发个 post 让别人 cover 你 1-2 件事 — 然后睡 8 小时。明天再说。',
    priority: 5,
    flag: 'priya_stress_checked',
  },
];

/**
 * 扫描所有 hook，返回当前应该触发的（满足 condition 且未 seen）。
 */
// 哪些 NPC 算"无需先认识"——室友/家人/Link2Ur 客服 cold message 都 OK
const PROACTIVE_NO_INTRO_REQUIRED = new Set(['mom', 'tom', 'mark', 'priya']);

export function scanProactiveChats(state) {
  const seen = new Set(state.seenProactiveHooks || []);
  const triggered = [];
  for (const hook of PROACTIVE_CHAT_HOOKS) {
    if (seen.has(hook.id)) continue;
    if (!CHAT_NPC_META[hook.npcId]) continue;
    // 自动门槛：除了 family/flatmate/priya，其它 NPC 必须 rel>=1 或 storyProgress>=1
    // 才能主动找你聊。防止陌生人冷不丁发来"上次见面挺好"这种穿帮。
    if (!PROACTIVE_NO_INTRO_REQUIRED.has(hook.npcId)) {
      const rel = (state.npcRel || {})[hook.npcId] || 0;
      const sp  = (state.storyProgress || {})[hook.npcId] || 0;
      if (rel < 1 && sp < 1) continue;
    }
    let pass = false;
    try { pass = !!hook.condition(state); }
    catch (e) { pass = false; }
    if (pass) triggered.push(hook);
  }
  // 按 priority 倒序 —— 数字越大越优先（最多一天 fire 2 条避免 spam）
  triggered.sort((a, b) => (b.priority || 0) - (a.priority || 0));
  return triggered.slice(0, 2);
}
