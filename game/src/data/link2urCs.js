// Link2Ur 客服小助手「小U」— 在微信里发指引消息的 NPC。
//
// 设计原则（重要）：
// 1. 总共 4 条消息上限。每条用 flag 锁，发过就 done。
// 2. 默认沉默——只在玩家完成里程碑时主动找一次。
// 3. 文案不写"亲~"、不卖话术，写得像 product 团队里一个真人 ops。
// 4. 每条延迟 600-1500ms，模仿"打字中"的等待感。
//
// 不做的事：
// - 不每周问候
// - 不推任务/活动
// - 不弹 modal——所有信息只在微信消息列表里出现

import { getUnlockedReviews } from './link2urReviews.js';

export const LINK2UR_CS_MESSAGES = [
  {
    id: 'cs_welcome',
    flag: 'l2u_cs_welcomed',
    delayMs: 1200,
    condition: ({ flags = {} }) =>
      !!flags.link2ur_discovered && !flags.l2u_cs_welcomed,
    text:
      '👋 你好，我是小 U——Link2Ur 平台的助手，留学生互助平台运营官。\n\n'
      + '你已经过了实名审核。三件事知道一下就行：\n'
      + '· 接单赚钱，发单解放时间，每周一刷新\n'
      + '· 评分 4.8+ 会被推给优质客户\n'
      + '· 出问题在 app 里点举报，我会跟进\n\n'
      + '不打扰你了。需要我时找我。',
  },
  {
    id: 'cs_first_task',
    flag: 'l2u_cs_first_task',
    delayMs: 800,
    condition: ({ flags = {}, link2urCompleted }) =>
      !!flags.link2ur_discovered
      && !flags.l2u_cs_first_task
      && (link2urCompleted?.length || 0) >= 1,
    text:
      '🎉 第一单完成。\n\n'
      + '小 tips：客户给好评是一回事，回头客是另一回事。'
      + '如果有客户主动找你接第二单，那就是真站住脚了。\n\n'
      + '——加油，我去忙别的了。',
  },
  {
    id: 'cs_first_review',
    flag: 'l2u_cs_first_review',
    delayMs: 1500,
    condition: (state) =>
      !!state.flags?.link2ur_discovered
      && !state.flags?.l2u_cs_first_review
      && getUnlockedReviews(state).length >= 1,
    text:
      '⭐ 你收到了第一条具名好评。\n\n'
      + '具名留言比五星打分重要 10 倍——这意味着客户愿意把名字签在'
      + '你的 profile 上。我看了一眼，写得很真。\n\n'
      + '记得去 app 评价 tab 看看，截图也行。',
  },
  {
    id: 'cs_veteran',
    flag: 'l2u_cs_veteran',
    delayMs: 1000,
    condition: ({ flags = {}, link2urCompleted }) =>
      !!flags.link2ur_discovered
      && !flags.l2u_cs_veteran
      && (link2urCompleted?.length || 0) >= 10,
    text:
      '🏅 10 单达成。\n\n'
      + '后台数据显示你目前在伦敦 Link2Ur 用户里属于 active 前 8%。'
      + '我们运营组讨论过，准备把你列到下届迎新引导案例里——'
      + '不留名，只用数字。可以吗？\n\n'
      + '（不回我也行，默认同意。这事没那么严肃。）',
  },
  {
    id: 'cs_phase_pivot',
    flag: 'l2u_cs_phase_pivot',
    delayMs: 1200,
    condition: ({ flags = {}, link2urPhase }) =>
      link2urPhase === 2 && !flags.l2u_cs_phase_pivot,
    text:
      '🚀 你升 Phase 2 了。\n\n'
      + '我看了一眼后台 — 客户跟你三个月前不一样了, 单价跳, '
      + '撑住, 这是好事。\n\n'
      + '——你做得对。',
  },
  {
    id: 'cs_mama_call',
    flag: 'l2u_cs_mama_call',
    delayMs: 1500,
    condition: ({ flags = {} }) =>
      !!flags.l2u_mama_call_during_merger && !flags.l2u_cs_mama_call,
    text:
      '🪧 妈妈电话之后多说一句:\n\n'
      + '不管你选哪个 — 留下/回去/合并/独立 — '
      + '我们这边的数据都说你做出来过。\n\n'
      + '这是真的。',
  },

  // ── 首次触发型预警 (v11.1)·只在玩家第一次踩到红线时各发一条 ──
  {
    id: 'cs_low_wallet_warn',
    flag: 'l2u_cs_low_wallet',
    delayMs: 1200,
    condition: ({ flags = {}, stats = {} }) =>
      !flags.l2u_cs_low_wallet && (stats.wallet ?? 0) < 500,
    text:
      '💰 后台扫了一眼——你卡里 < £500 了。\n\n'
      + '不是要 push 你接单。是 heads up 一下:\n'
      + '· 每漏一顿饭夜里自动扣 £15 外卖费——这事悄悄就负数了\n'
      + '· 钱包真到 0 以下就回不去了\n\n'
      + 'Board 上跑腿单 £15-£25 一单。要的话点开 app。',
  },
  {
    id: 'cs_no_meal_warn',
    flag: 'l2u_cs_no_meal',
    delayMs: 1500,
    condition: ({ flags = {} }) =>
      !flags.l2u_cs_no_meal && !!flags.first_no_meal_day,
    text:
      '🛵 看到你昨天一顿没吃，深夜自动 Deliveroo 扣了 £30。\n\n'
      + '说一句不是管你:漏顿饭压力涨得最狠 (+8),'
      + '比 essay 没写完还狠。\n\n'
      + '即使是 Tesco Meal Deal £3.40——也比挨饿+£15 外卖+8 压力划算。',
  },
  {
    id: 'cs_stress_first_warn',
    flag: 'l2u_cs_stress_first',
    delayMs: 1000,
    condition: ({ flags = {}, stress = 25 }) =>
      !flags.l2u_cs_stress_first && stress >= 60,
    text:
      '📈 你压力指数第一次摸到 60。\n\n'
      + '机制说清楚一遍——之后你不会再收到这条:\n'
      + '· 60-74:表现轻微下滑 (energy/academic 慢扣)\n'
      + '· 75-84:**行动点变 2 个/天**\n'
      + '· 85-94:**行动点变 1 个/天** + belonging/energy 重扣\n'
      + '· 95 + :burnout 失败 ending\n\n'
      + '解压最快的两条路:发 Link2Ur post (-18 stress 一发)、接单 (-12)。',
  },
];

/**
 * Find CS messages whose condition is satisfied AND whose gating flag is not
 * yet set. Caller is responsible for dispatching addMessage + flag set.
 */
export function getEligibleCsMessages(state) {
  return LINK2UR_CS_MESSAGES.filter((m) => {
    try { return !!m.condition(state); } catch (_) { return false; }
  });
}
