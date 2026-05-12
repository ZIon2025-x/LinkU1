// Link2Ur 创业线 · 6 条跨圈联动事件 (spec §8)
// 把 Y 姐线和其他 6 主线 NPC 缝合的关键节点

export const LINK2UR_CROSSOVERS = [
  {
    id: 'cross_yjie_wangkai_pub',
    title: '王凯 Soho pub 偶遇 Y 姐',
    trigger: (s) => {
      const w = Math.ceil(s.day / 7);
      return w >= 26 && w <= 30 && (s.npcRel?.wangkai || 0) >= 5 && s.link2urPath === 'team';
    },
    narrative: `王凯吃饭跟玩家: "那 Y 姐有意思啊 哥们感觉她想撬你的 AI 团队跟她合并。
你小心点啊。她那种人, 谈生意都说 'finesse', 听着就比咱们文。
但你跟她比的是品牌, 不是融钱。你的 AI 比她的旅游更新, 你 leverage 更大。"`,
  },
  {
    id: 'cross_yjie_whitmore_indirect',
    title: 'Whitmore office hour 提一句',
    trigger: (s) => {
      const w = Math.ceil(s.day / 7);
      return w >= 33 && w <= 37 && (s.link2urCompleted?.length || 0) >= 18 && (s.npcRel?.whitmore || 0) >= 4;
    },
    narrative: `Whitmore 在 office hour 突然停下来:
"Heard you\'ve built an AI thing on that platform. Link2Ur, was it?
That\'s clever. Make sure it\'s still you doing the thinking, not the machine.
Now — back to Foucault."`,
  },
  {
    id: 'cross_yjie_mei_dinner',
    title: 'Y 姐带 Bespoke 客户来 Mei\'s 吃饭',
    trigger: (s) => {
      const w = Math.ceil(s.day / 7);
      return w >= 30 && (s.npcRel?.mei || 0) >= 4 && s.link2urPath === 'team';
    },
    narrative: `Mei 私下跟玩家: "这丫头是个聪明姑娘, 不过我得告诉你 — 小心被她搞累。
她跟你王凯不一样 — 王凯亲, 她精。她吃饭的时候我看了, 给客户夹菜的手势特别熟。
那种熟不是天生的, 是练的。
你跟她合作可以。但别全押她。"`,
  },
  {
    id: 'cross_yjie_aditi_referral',
    title: 'Aditi 想找 AI 翻译兼职',
    trigger: (s) => {
      const w = Math.ceil(s.day / 7);
      return w >= 22 && w <= 30 && (s.npcRel?.aditi || 0) >= 5;
    },
    narrative: `Aditi 论文写完跟玩家说: "I want to do some freelance AI translation/academic proofread.
Do you have a referral pipeline? Yvonne 那边可以接吗?"`,
    choices: [
      {
        label: '推给 Y 姐网络',
        effect: { npc: { aditi: 3, yjie: 1 }, flag: 'l2u_aditi_referred_yjie' },
        feedback: 'Aditi 加入 Y 姐 referral 网络。她每月通过 referral 接 4-5 个学术 AI 单, 月入 £400 补贴生活。你心里有点 mixed feelings — 帮了 Aditi, 但客户分流了。',
      },
      {
        label: '自留 (你的客户)',
        effect: { npc: { aditi: 1 }, flag: 'l2u_aditi_stayed_yours' },
        feedback: 'Aditi 加入你的客户池。她做你的学术 AI 单, 你做她的"客户"。这种 dynamic 一开始有点尴尬, 后来变成你们最深的友谊之一。',
      },
    ],
  },
  {
    id: 'cross_wangkai_eric_steal',
    title: '王凯也要 Eric 做奶茶店海报',
    trigger: (s) => {
      const w = Math.ceil(s.day / 7);
      return w >= 41 && w <= 45 && s.link2urPath === 'team' && s.flags?.l2u_team_recruited_eric;
    },
    narrative: `Soho 烤串店。王凯: "Eric 这两周给奶茶店做新菜单海报, 我让他暂停你的活两天。OK 吗?"`,
    choices: [
      {
        label: '让 Eric 自己选',
        effect: { npc: { wangkai: 0 }, flag: 'cross_eric_chose_self' },
      },
      {
        label: '涨 cut 留人',
        effect: { stats: { wallet: -200 }, npc: { wangkai: -3 }, flag: 'cross_eric_retained_with_raise' },
      },
      {
        label: '散伙让 Eric 走',
        effect: { stats: { wallet: -100 }, npc: { wangkai: 2 }, flag: 'cross_eric_left_to_wangkai' },
      },
    ],
  },
  {
    id: 'cross_yjie_paul_bbc',
    title: '🔴 Paul BBC "AI 时代 immigrant labor" 专题',
    trigger: (s) => {
      const w = Math.ceil(s.day / 7);
      const paulRel = s.link2urRepeatCustomers?.cust_paul?.count || 0;
      return w >= 37 && w <= 39 && paulRel >= 4 && (s.link2urCompleted?.length || 0) >= 25;
    },
    narrative: `Paul DM: "I'm doing a BBC long-form on 'AI Times: Immigrant Labor in the Age of Algorithms'.
You're one of the 5 subjects. I want 90 min interview, on camera.

Y 姐 is also on my list. Want to do a joint shot or solo?

Questions I'll ask:
- AI 帮你做了多少 vs 你自己做了多少?
- 你觉得自己是被 AI 替代的人 还是替代别人的人?
- 在英国做 AI 内容, 跟在中国做有什么不同?"`,
    choices: [
      {
        label: '"Joint shot with Y 姐"',
        effect: {
          stats: { belonging: 10 },
          npc: { yjie: 3 },
          flag: 'l2u_paul_interview_done',
          flag2: 'l2u_paul_joint_with_yjie',
          flag3: 'l2u_ai_anxiety_resolved',
        },
      },
      {
        label: '"Solo, I want my own narrative"',
        effect: {
          stats: { belonging: 8 },
          flag: 'l2u_paul_interview_done',
          flag2: 'l2u_paul_solo',
          flag3: 'l2u_ai_anxiety_resolved',
        },
      },
      {
        label: '"Pass for now, my thesis is at 4 weeks out"',
        effect: { stats: { academic: 3 }, flag: 'l2u_paul_interview_declined' },
      },
    ],
  },
];

export function getEligibleCrossovers(state) {
  return LINK2UR_CROSSOVERS.filter((c) => {
    try {
      return c.trigger(state) && !state.flags?.[`crossover_seen_${c.id}`];
    } catch (e) {
      return false;
    }
  });
}
