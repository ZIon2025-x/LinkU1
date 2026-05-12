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
