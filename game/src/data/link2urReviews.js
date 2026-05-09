// Link2Ur 评价 — 已结识的 NPC 在 Link2Ur 上留下的具名 5 星留言。
//
// 设计：玩家在游戏世界里结交某人后（解锁对应 flag），那个人会"反过来"
// 在 Link2Ur 平台留 5 星 + 一句留言，让 Link2Ur 不只是匿名外包平台，
// 而是把"你的朋友圈"映射回 app 里的关系网。
//
// 条件设计要求 link2urCompleted >= N，意味着玩家必须 *活跃用平台*
// 才会解锁评价——这是对玩家投入度的奖励，不是无脑挂出来的彩蛋。
//
// 集齐 3+ → 触发 achievements.js 里的新成就 'link2ur_trusted'。

export const LINK2UR_REVIEWS = [
  {
    id: 'review_aisha',
    from: 'Aisha',
    role: 'KCL · 同班同学',
    avatar: '🌙',
    avatarColor: '#7a9ec0',
    starCount: 5,
    weekHint: '斋月那周',
    message:
      '我室友斋月晚上需要 iftar 食材，这个朋友帮我跑 Whitechapel '
      + '15 分钟到 + 还顺手买了我妈最爱的 dates。Salam，you\'re a real one.',
    condition: ({ flags = {}, link2urCompleted }) =>
      !!flags.aisha_friend && (link2urCompleted?.length || 0) >= 1,
  },
  {
    id: 'review_park',
    from: 'Park',
    role: 'KCL Music · 大三',
    avatar: '🎻',
    avatarColor: '#9c7ab8',
    starCount: 5,
    weekHint: 'Concert 之前',
    message:
      'My violin bow broke 3 hours before recital. This person ran '
      + 'Westminster → Wigmore → KCL with the rehair. Lifesaver. '
      + '感谢中文谢谢 (I learned that word for you).',
    condition: ({ flags = {}, link2urCompleted }) =>
      !!flags.park_concert && (link2urCompleted?.length || 0) >= 2,
  },
  {
    id: 'review_cssa',
    from: 'CSSA · 伦敦分会',
    role: '官方账号',
    avatar: '🏮',
    avatarColor: '#c4615a',
    starCount: 5,
    weekHint: '迎新季',
    message:
      '👏 感谢这位同学今年帮过 CSSA 多个新生（取 BRP / 找房 / 翻译）。'
      + '后台推荐评分 4.9。我们准备把 ta 的故事放到下届迎新手册里——'
      + '"留学生互助"不是口号，是真实存在的。',
    condition: ({ flags = {}, link2urCompleted, link2urRating }) =>
      !!flags.cssa
      && (link2urCompleted?.length || 0) >= 3
      && (link2urRating || 0) >= 4.5,
  },
  {
    id: 'review_marcus',
    from: 'Marcus',
    role: 'LSE · 同 diaspora',
    avatar: '✊',
    avatarColor: '#7a6552',
    starCount: 5,
    weekHint: '某个深夜',
    message:
      'Asked for help with a heavy emotional task — translating some '
      + 'BS from a landlord who was racist as hell. They didn\'t just '
      + 'translate. They drafted my response. Solidarity from one immigrant kid '
      + 'to another. ✊',
    condition: ({ flags = {}, link2urCompleted }) =>
      !!flags.marcus_solidarity && (link2urCompleted?.length || 0) >= 2,
  },
  {
    id: 'review_tom',
    from: 'Tom',
    role: '同 flat · 英国本地',
    avatar: '🍻',
    avatarColor: '#7a8a6a',
    starCount: 5,
    weekHint: 'Eurovision 之后某天',
    message:
      'Mate. They taught me how to make 麻婆豆腐 in exchange for me showing '
      + 'them how to claim my £150 council tax refund. Best trade of the year.'
      + ' Top human. 100% would Sunday roast again.',
    condition: ({ flags = {}, link2urCompleted }) =>
      !!flags.tom_friend && (link2urCompleted?.length || 0) >= 1,
  },
  {
    id: 'review_mei',
    from: 'Mei 姐',
    role: 'Lucky Star Mei\'s · 老板娘',
    avatar: '🥡',
    avatarColor: '#b85070',
    starCount: 5,
    weekHint: '论文季',
    message:
      '这孩子论文季还来店里帮我搬一箱新到的辣椒酱，没让我给钱。'
      + '我留了一份红烧肉给 ta 第二天来吃。\n\n'
      + '——这年头 5 星不够用。Mei\'s 给 ta 加 1 星：6 星。',
    condition: ({ flags = {}, link2urCompleted }) =>
      !!flags.mei_serving && (link2urCompleted?.length || 0) >= 4,
  },
];

/**
 * Filter reviews to those currently unlocked by player's state.
 */
export function getUnlockedReviews(state) {
  return LINK2UR_REVIEWS.filter((r) => {
    try { return !!r.condition(state); } catch (_) { return false; }
  });
}
