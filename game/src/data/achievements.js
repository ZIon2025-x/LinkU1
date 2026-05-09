import { getUnlockedReviews } from './link2urReviews.js';

// Achievement definitions — 40+ unlockable cards.
//
// Each achievement has a `check(state)` predicate. The engine evaluates these
// against the live game state and unlocks new ones automatically. Once unlocked
// the player can click the card in Diary tab to view + share/download a
// Polaroid-style PNG of the achievement.
//
// Tiers (and Polaroid photo background colour):
//   common      gray   – everyday milestones
//   rare        blue   – completed sub-arcs (NPC friends, opt-in flags)
//   epic        purple – heavy emotional beats
//   legendary   gold   – rare flag combinations / endings

export const ACHIEVEMENTS = [
  // ─────────────────────────── COMMON ───────────────────────────
  {
    id: 'arrived', tier: 'common', icon: '✈️',
    title: '落地伦敦',
    desc: '从 Heathrow T3 走出来的那一刻。',
    check: ({ flags = {} }) =>!!(flags.arrival_tube || flags.arrival_express || flags.arrival_cab),
  },
  {
    id: 'brp_collected', tier: 'common', icon: '🛂',
    title: 'BRP 收集者',
    desc: '10 天内取了那张粉色塑料卡。',
    check: ({ flags = {} }) =>!!flags.brp_collected,
  },
  {
    id: 'gp_registered', tier: 'common', icon: '🩺',
    title: 'NHS 入门',
    desc: '填了 GMS1 表。免费看病的入场券。',
    check: ({ flags = {} }) =>!!flags.gp_registered,
  },
  {
    id: 'council_tax_exempt', tier: 'common', icon: '📨',
    title: 'Council Tax 豁免',
    desc: '一封邮件省 £1,500/年。',
    check: ({ flags = {} }) =>!!flags.council_tax_exempt,
  },
  {
    id: 'student_oyster', tier: 'common', icon: '🎫',
    title: '18+ Student Oyster',
    desc: '£20 一次性，30% 通勤折扣终身。',
    check: ({ flags = {} }) =>!!flags.student_oyster,
  },
  {
    id: 'monzo_open', tier: 'common', icon: '💳',
    title: 'Monzo 用户',
    desc: '5 分钟开户。黄色实体卡 3 天到。',
    check: ({ flags = {} }) =>!!flags.monzo_open,
  },
  {
    id: 'enrolled', tier: 'common', icon: '🎓',
    title: '正式注册',
    desc: '学生卡到手——图书馆 / 折扣 / 一切的钥匙。',
    check: ({ flags = {} }) =>!!flags.enrolled,
  },
  {
    id: 'cssa_joined', tier: 'common', icon: '🏮',
    title: 'CSSA 一员',
    desc: '加入 200 人微信群。这一年最不该退的群。',
    check: ({ flags = {} }) =>!!flags.cssa,
  },
  {
    id: 'fire_alarm_witnessed', tier: 'common', icon: '🚨',
    title: '凌晨 3 点烟雾警报',
    desc: '60 个 housemate 一起穿睡衣站雨里。',
    check: ({ flags = {} }) =>!!flags.fire_alarm_witnessed,
  },
  {
    id: 'pret', tier: 'common', icon: '☕',
    title: '第一次 Pret',
    desc: 'Bloomsbury 街角长椅 + 一杯 flat white。这是伦敦的早餐节奏。',
    check: ({ flags = {} }) =>!!flags.first_pret,
  },
  {
    id: 'yellow_label', tier: 'common', icon: '🏷️',
    title: 'Tesco 抢黄标',
    desc: '晚 9 点的 reduced sticker。一盒 sushi 省 70%。',
    check: ({ flags = {} }) =>!!flags.yellow_label_grabbed,
  },
  {
    id: 'apple_pay_default', tier: 'common', icon: '📱',
    title: 'Apple Pay 派',
    desc: '发现 contactless 也能刷 Tube。',
    check: ({ flags = {} }) =>!!flags.apple_pay_default,
  },
  {
    id: 'clubcard', tier: 'common', icon: '🛒',
    title: 'Tesco Clubcard',
    desc: '5 分钟省一年 £200+。',
    check: ({ flags = {} }) =>!!flags.clubcard,
  },

  // ─────────────────────────── RARE ───────────────────────────
  {
    id: 'tom_friend', tier: 'rare', icon: '🍻',
    title: 'Tom 的朋友',
    desc: 'fire alarm 那晚的"无奈一笑"开始的友谊。',
    check: ({ flags = {} }) =>!!flags.tom_friend,
  },
  {
    id: 'tom_roast', tier: 'rare', icon: '🍗',
    title: 'Sunday Roast',
    desc: '英国家庭 4 小时午餐。Yorkshire pudding 像云朵。',
    check: ({ flags = {} }) =>!!flags.tom_roast,
  },
  {
    id: 'mark_friend', tier: 'rare', icon: '🍳',
    title: 'Mark 的洗锅老师',
    desc: '小苏打 + 白醋蹲水池 30 分钟。',
    check: ({ flags = {} }) =>!!flags.mark_friend,
  },
  {
    id: 'mei_serving', tier: 'rare', icon: '🥡',
    title: 'Mei 姐徒弟',
    desc: '红围裙系上。第一次靠自己赚到英镑。',
    check: ({ flags = {} }) =>!!flags.mei_serving,
  },
  {
    id: 'cotswolds_visited', tier: 'rare', icon: '🏡',
    title: 'Cotswolds 周末',
    desc: 'Sarah 妈做的三种 stuffing。',
    check: ({ flags = {} }) =>!!flags.cotswolds_visited,
  },
  {
    id: 'wangkai_business', tier: 'rare', icon: '🧋',
    title: '奶茶店合伙人',
    desc: '王凯 Camden 那杯咖啡之后的握手。',
    check: ({ flags = {} }) =>!!flags.wangkai_business,
  },
  {
    id: 'whitmore_coffee', tier: 'rare', icon: '☕',
    title: 'Senior Common Room',
    desc: 'Whitmore 邀请你喝咖啡谈期刊文章。',
    check: ({ flags = {} }) =>!!flags.whitmore_coffee,
  },
  {
    id: 'bicester_daigou', tier: 'rare', icon: '🛍️',
    title: 'Bicester 代购',
    desc: '扛 4 个 Burberry 包回伦敦。',
    check: ({ flags = {} }) =>!!flags.bicester_daigou,
  },
  {
    id: 'aisha_friend', tier: 'rare', icon: '🌙',
    title: 'Aisha 的斋月伙伴',
    desc: '你们一起 break fast 的那颗椰枣。',
    check: ({ flags = {} }) =>!!flags.aisha_friend,
  },
  {
    id: 'eid_lunch', tier: 'rare', icon: '🍛',
    title: 'Eid · Hounslow 的一桌',
    desc: '25 个亲戚围一桌 biryani。',
    check: ({ flags = {} }) =>!!flags.eid_lunch,
  },
  {
    id: 'marcus_solidarity', tier: 'rare', icon: '✊',
    title: '"Welcome to the club"',
    desc: 'Cross-diaspora friendship。"Stop carrying it home with you."',
    check: ({ flags = {} }) =>!!flags.marcus_solidarity,
  },
  {
    id: 'park_concert', tier: 'rare', icon: '🎻',
    title: 'Park 的 Bach Partita',
    desc: 'KCL Music 学生 concert 第一排。',
    check: ({ flags = {} }) =>!!flags.park_concert,
  },
  {
    id: 'eurovision_party', tier: 'rare', icon: '📺',
    title: 'Eurovision 之夜',
    desc: '5 个人挤 Tom 床上喊 BBC One。',
    check: ({ flags = {} }) =>!!flags.eurovision_party,
  },
  {
    id: 'house_meeting', tier: 'rare', icon: '🧹',
    title: 'House Meeting 参与者',
    desc: '90 分钟讨论 cleaning rota——英国式 democracy 入门课。',
    check: ({ flags = {} }) =>!!flags.house_meeting_attended,
  },
  {
    id: 'cssa_dimsum', tier: 'rare', icon: '🥟',
    title: 'Chinatown 早茶',
    desc: '6 个人挤一桌肠粉。买单一起抢。',
    check: ({ flags = {} }) =>!!flags.cssa,  // approximated — relies on player having CSSA
  },
  {
    id: 'bonfire_night_park', tier: 'rare', icon: '🎆',
    title: 'Hyde Park 烟花',
    desc: '英国老夫妇递的那杯热可可。',
    check: ({ flags = {} }) =>false,  // placeholder — hook into bonfire choice flag if added
  },

  // ─────────────────────────── EPIC ───────────────────────────
  {
    id: 'parents_visited', tier: 'epic', icon: '🇨🇳',
    title: '父母来过',
    desc: 'Heathrow T3 那个拥抱。"对不起 这一年让你一个人。"',
    check: ({ flags = {} }) =>!!flags.parents_visited,
  },
  {
    id: 'sent_money_home', tier: 'epic', icon: '💰',
    title: '"妈这是我赚的"',
    desc: '第一次往家里转 ¥2,000。',
    check: ({ flags = {} }) =>!!flags.sent_first_money_home,
  },
  {
    id: 'crisis_survived', tier: 'epic', icon: '🌅',
    title: '4:38 AM 撑过来了',
    desc: '凌晨想订机票回去——但你没。',
    check: ({ flags = {} }) =>!!flags.recent_nostalgia,  // proxy; can refine later
  },
  {
    id: 'visited_india', tier: 'epic', icon: '🪔',
    title: '孟买 35 度',
    desc: '陪 Aditi 去印度看她爸爸。',
    check: ({ flags = {} }) =>!!flags.visited_india,
  },
  {
    id: 'linnan_dating', tier: 'epic', icon: '💞',
    title: 'Trafalgar 跨年告白',
    desc: 'South Bank 的接吻。冷得鼻子都冻了。',
    check: ({ flags = {} }) =>!!flags.linnan_dating,
  },
  {
    id: 'mei_family', tier: 'epic', icon: '🧧',
    title: '叫一声"姨"',
    desc: '17 道菜的圣诞夜。Mei 转身去厨房擦眼睛。',
    check: ({ flags = {} }) =>!!flags.mei_family,
  },
  {
    id: 'high_table', tier: 'epic', icon: '🍷',
    title: 'College High Table',
    desc: '黑领结 + 雪利酒 + Lord Kerridge 笑了。',
    check: ({ flags = {} }) =>!!flags.high_table,
  },
  {
    id: 'oxford_ref', tier: 'epic', icon: '🏛️',
    title: '"You should apply"',
    desc: 'Whitmore 的推荐信草稿。眼泪掉到纸上。',
    check: ({ flags = {} }) =>!!flags.oxford_ref,
  },
  {
    id: 'psw_applied', tier: 'epic', icon: '📜',
    title: '£2,374 Graduate Visa',
    desc: '买的不是 visa——是 2 年留下来的权利。',
    check: ({ flags = {} }) =>!!flags.psw_applied,
  },
  {
    id: 'flew_home_dad', tier: 'epic', icon: '✈️',
    title: '"我想见你"',
    desc: '爸爸支架手术，£1,200 改的当天机票。',
    check: ({ flags = {} }) =>!!flags.flew_home_emergency,
  },
  {
    id: 'graduated', tier: 'epic', icon: '🎉',
    title: '毕业',
    desc: '紫金 hood 走过台。head of department 念错了你的名字。',
    check: ({ flags = {} }) =>!!flags.graduated,
  },

  // ─────────────────────────── LEGENDARY ───────────────────────────
  {
    id: 'sarah_double', tier: 'legendary', icon: '🌹',
    title: 'Sarah 的最佳损友',
    desc: 'Cotswolds 圣诞 + 5 国欧洲穷游。一辈子的朋友。',
    check: ({ flags = {} }) =>!!(flags.cotswolds_xmas && flags.eurotrip_sarah),
  },
  {
    id: 'aditi_double', tier: 'legendary', icon: '🤝',
    title: 'You have me. Always.',
    desc: '印度行 + 7am pact。世界上最长的友谊。',
    check: ({ flags = {} }) =>!!(flags.visited_india && flags.easter_aditi_pact),
  },
  {
    id: 'mei_double', tier: 'legendary', icon: '⭐',
    title: 'Lucky Star 少东家',
    desc: 'Mei 家 + 4 周经理。"30% 干股。叫姨我给 35%。"',
    check: ({ flags = {} }) =>!!(flags.mei_family && flags.mei_manager),
  },
  {
    id: 'whitmore_double', tier: 'legendary', icon: '📰',
    title: '《剑桥评论》作者',
    desc: 'High Table + 论文 polished。"Call me James."',
    check: ({ flags = {} }) =>!!(flags.high_table && flags.thesis_polished),
  },
  {
    id: 'wangkai_double', tier: 'legendary', icon: '💼',
    title: 'Forbes 30 Under 30',
    desc: '£2,500 那夜 + 复活节学徒。32 家奶茶店。',
    check: ({ flags = {} }) =>!!(flags.xmas_grind && flags.wangkai_apprentice),
  },
  {
    id: 'distinction_parents', tier: 'legendary', icon: '👨‍👩‍👧',
    title: '"是这孩子让我们这一辈子值了"',
    desc: '父母来过 + 学业 ≥ 70。爸罕见地发了朋友圈。',
    check: ({ flags = {}, stats = {} }) => !!flags.parents_visited && (stats.academic || 0) >= 70,
  },
  {
    id: 'linnan_forever', tier: 'legendary', icon: '🏠',
    title: 'Hackney 二居二人组',
    desc: '一起留下 + 5 年后买房 + ta 妈终于摆了第二双筷子。',
    check: ({ flags = {} }) =>!!flags.linnan_stay_together,
  },
  {
    id: 'link2ur_5star', tier: 'legendary', icon: '🌟',
    title: 'Link2Ur 五星老用户',
    desc: '完成 5+ 任务 · 评分 ≥ 4.8。',
    check: ({ link2urCompleted, link2urRating }) => (link2urCompleted?.length || 0) >= 5 && (link2urRating || 0) >= 4.8,
  },
  {
    id: 'link2ur_trusted', tier: 'legendary', icon: '🤝',
    title: '信得过的人',
    desc: 'Link2Ur 评价里 3 个具名朋友写过你的留言——这些不是任务结算，是 reputation。',
    check: (state) => getUnlockedReviews(state).length >= 3,
  },
  {
    id: 'ilr_eligible', tier: 'legendary', icon: '🎯',
    title: '留下来的人',
    desc: 'PSW + 第一份英国 offer。这是你的伦敦。',
    check: ({ flags = {} }) =>!!flags.stayed_uk_grad,
  },
];

/**
 * Compute the set of achievements satisfied by the current state.
 * Returns array of ids (subset of ACHIEVEMENTS).
 */
export function computeUnlocked(state) {
  return ACHIEVEMENTS.filter(a => {
    try { return !!a.check(state); } catch (_) { return false; }
  }).map(a => a.id);
}

/**
 * Build a map id → metadata for fast lookups.
 */
export const ACHIEVEMENT_BY_ID = Object.fromEntries(
  ACHIEVEMENTS.map(a => [a.id, a]),
);

export const TIER_META = {
  common:    { label: 'COMMON',    photoBg: '#2a2520', accent: '#8a8a8a', borderColor: 'rgba(232,224,208,0.3)' },
  rare:      { label: 'RARE',      photoBg: '#2c4a6e', accent: '#aac0d8', borderColor: 'rgba(170,192,216,0.6)' },
  epic:      { label: 'EPIC',      photoBg: '#5e3870', accent: '#d8b8e8', borderColor: 'rgba(216,184,232,0.6)' },
  legendary: { label: 'LEGENDARY', photoBg: '#8a6b2a', accent: '#FFD700', borderColor: 'rgba(255,215,0,0.7)' },
};
