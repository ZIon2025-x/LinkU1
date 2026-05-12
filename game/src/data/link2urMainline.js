// Link2Ur 创业线 · 9 章主线事件链 (spec §6)
//
// 每章 events 数组列出该章关键事件 (按周触发)。
// 关键事件类型:
//   - npc_scene: 引用 npcYjie.js 里的某个 YJIE_SCENES 项
//   - customer_unlock: 某个 customer 晋升到指定 relationship
//   - inbox_task: 触发某个客户的指定任务
//   - clash_trigger: 触发 clash event
//   - mini_arc: 触发某团员 mini-arc 阶段
//   - crossover: 引用 link2urCrossover.js
//   - flag_set: 设置某个 flag
//
// App.jsx 的 tick 循环每周扫一次 active chapter 的 events,
// 根据 trigger 条件 dispatch action。

export const LINK2UR_CHAPTERS = [
  // ── Ch 1 · W2-W7 · 试水 ──
  {
    chapterId: 'link2ur_ch1',
    title: '试水',
    weekStart: 2,
    weekEnd: 7,
    summary: 'Phase 1 起步。玩家用 Link2Ur 接 2-3 个简单 AI 小单 (双语字幕 / IG 海报 AI 加工)。第一个客户给五星记住你了。',
    events: [
      {
        id: 'ch1_first_simple_task',
        week: 3,
        type: 'inbox_task',
        customerId: null,  // board 单, 还没 inbox
        narrative: '你接了第一个 AI 双语字幕单 (Loon Fung 跑腿单的升级版)',
      },
      {
        id: 'ch1_lily_first_repeat',
        week: 6,
        type: 'customer_unlock',
        customerId: 'cust_lily',
        relationship: 'first_impression',
        narrative: 'Lily 给你五星 + 留言 "下次再约"',
        flagOnSet: 'l2u_first_repeat_unlocked',
      },
    ],
  },

  // ── Ch 2 · W8-W12 · 第一个回头客 ──
  {
    chapterId: 'link2ur_ch2',
    title: '第一个回头客',
    weekStart: 8,
    weekEnd: 12,
    summary: 'Lily 通过 inbox 发首个指定单 (双语短视频 5 条 +20% VIP)。Marcus 加入。Essay 危机时可能拒接, 关系倒退 (可恢复)。',
    events: [
      {
        id: 'ch2_lily_first_inbox',
        week: 8,
        type: 'inbox_task',
        customerId: 'cust_lily',
        title: 'Lily · 双语短视频 5 条 + 20% VIP',
        reward: 180,
        narrative: '"上次那个 AI 字幕做的特别好, 这次代理品牌签约, 5 条短视频本周内出。"',
        flagOnAccept: 'l2u_first_inbox_accepted',
      },
      {
        id: 'ch2_marcus_first_repeat',
        week: 10,
        type: 'customer_unlock',
        customerId: 'cust_marcus_p1',
        relationship: 'first_impression',
        narrative: 'Marcus 找你做"留学生反诈"系列双语长图文',
      },
      {
        id: 'ch2_essay_clash',
        week: 11,
        type: 'flag_set',
        flagOnSet: 'l2u_inbox_unlocked',
        narrative: 'Essay 危机叠加 (主线 Whitmore 62 分时刻), 玩家可能拒一个 inbox 任务',
      },
    ],
  },

  // ── Ch 3 · W13-W17 · 撞档·初体验 ──
  {
    chapterId: 'link2ur_ch3',
    title: '撞档·初体验',
    weekStart: 13,
    weekEnd: 17,
    summary: '圣诞期 demand 飙升。Lily + 张奶奶 + 陈一帆 三任务撞档。Lily W17 被中资品牌相中签约 (Phase 2 hook 预埋)。',
    events: [
      {
        id: 'ch3_xmas_clash',
        week: 14,
        type: 'clash_trigger',
        narrative: '圣诞前三个客户同周发指定任务 → 第一次时间撞档',
      },
      {
        id: 'ch3_grandma_repeat',
        week: 12,
        type: 'customer_unlock',
        customerId: 'cust_grandma',
        relationship: 'first_impression',
        narrative: '张奶奶让你陪她去看金毛 + 顺便发个朋友圈',
      },
      {
        id: 'ch3_chen_repeat',
        week: 10,
        type: 'customer_unlock',
        customerId: 'cust_chen',
        relationship: 'first_impression',
        narrative: '陈一帆论文 first chapter 校对单',
      },
      {
        id: 'ch3_lily_signed',
        week: 17,
        type: 'flag_set',
        flagOnSet: 'l2u_lily_signed',
        narrative: 'Lily 被中资茶饮品牌相中签约, 告诉玩家 "可能要介绍你给品牌方" (Phase 2 hook)',
      },
    ],
  },

  // ── Ch 4 · W21-W22 · Sketch 下午茶 + Phase pivot ──
  {
    chapterId: 'link2ur_ch4',
    title: 'Sketch 下午茶',
    weekStart: 21,
    weekEnd: 22,
    summary: '父母走后撞档第 3 次 + Lily 正式介绍品牌方 → Y 姐 DM Sketch 邀请。无论玩家选什么 path, Phase 1 → 2 不可逆 pivot。',
    events: [
      {
        id: 'ch4_clash_third',
        week: 21,
        type: 'clash_trigger',
        narrative: '父母周末后第三次时间撞档 (累计 3 次, 满足 Y 姐邀请条件)',
      },
      {
        id: 'ch4_lily_brand_intro',
        week: 21,
        type: 'flag_set',
        flagOnSet: 'l2u_lily_brand_intro_pending',
        narrative: 'Lily 正式介绍蓝瓶茶饮 marketing director Carrie 给你',
      },
      {
        id: 'ch4_y_sketch_invite',
        week: 22,
        type: 'npc_scene',
        sceneId: 'yjie_sketch_invitation',
        narrative: 'Y 姐 inbox DM 约你 Sketch pink room 下午茶。三选一: 加入 Team / 委婉拒绝 / 限定接单',
      },
      {
        id: 'ch4_phase_pivot',
        week: 22,
        type: 'flag_set',
        flagOnSet: 'l2u_phase_2_active',
        statePatch: { link2urPhase: 2 },
        narrative: 'Phase 1 → 2 不可逆 pivot。玩家开始服务 Carrie / 品牌方,客单跳变。',
      },
    ],
  },

  // ── Ch 5 · W23-W26 · 第一步分化 ──
  {
    chapterId: 'link2ur_ch5',
    title: '第一步分化',
    weekStart: 23,
    weekEnd: 26,
    summary: '蓝瓶茶饮首单 £1200。Phase 1 客户 (Marcus / Jess) 部分流失或留下。Path A 玩家选 niche / Path B 招小雨。',
    events: [
      {
        id: 'ch5_brand_tea_first',
        week: 23,
        type: 'inbox_task',
        customerId: 'cust_brand_tea',
        title: '蓝瓶茶饮 · UK Launch Campaign',
        reward: 1200,
        narrative: 'Carrie: "我们 4 月 1 号 launch。 brief 后天给。如果做得好, 年度合约 retainer 直接谈。"',
        flagOnAccept: 'l2u_brand_tea_signed',
      },
      {
        id: 'ch5_marcus_introduces_paul',
        week: 23,
        type: 'flag_set',
        flagOnSet: 'l2u_marcus_paul_intro',
        narrative: 'Marcus 推荐 Paul (BBC 记者) 给你 — Phase 2 客户引荐 + 跨圈联动 hook',
      },
      // Path A · Solo
      {
        id: 'ch5_solo_capacity_limit',
        week: 24,
        type: 'flag_set',
        requireFlag: 'link2urPath_solo',
        flagOnSet: 'l2u_solo_capacity_learned',
        narrative: 'Solo 路径: 玩家学到"接单上限 N/周"机制 (UI slider 启用)',
      },
      {
        id: 'ch5_solo_niche_choice',
        week: 26,
        type: 'choice',
        requireFlag: 'link2urPath_solo',
        flagOnComplete: 'l2u_solo_niche_chosen',
        prompt: 'AI 4 专精方向 (4 选 1)',
        choices: [
          { id: 'ai_copy_pro', label: 'AI 文案专家', flag: 'l2u_solo_niche_copy' },
          { id: 'ai_visual_pro', label: 'AI 视觉专家', flag: 'l2u_solo_niche_visual' },
          { id: 'ai_video_pro', label: 'AI 视频专家', flag: 'l2u_solo_niche_video' },
          { id: 'ai_ads_pro', label: 'AI 投放策略专家', flag: 'l2u_solo_niche_ads' },
        ],
      },
      // Path B · Team
      {
        id: 'ch5_team_recruit_xiaoyu',
        week: 24,
        type: 'npc_scene',
        sceneId: 'yjie_team_referral_xiaoyu',
        requireFlag: 'link2urPath_team',
        narrative: 'Y 姐 DM 介绍小雨。玩家面谈后决定是否招人',
      },
      {
        id: 'ch5_team_assign_learned',
        week: 26,
        type: 'flag_set',
        requireFlag: 'l2u_team_recruited_xiaoyu',
        flagOnSet: 'l2u_team_assign_learned',
        narrative: 'Team 路径: 玩家学到 inbox 分单机制 (UI assign button 启用)',
      },
    ],
  },
  // ── Ch 6 · W27-W30 · 复活节深化 + Omar 上线 ──
  {
    chapterId: 'link2ur_ch6',
    title: '复活节深化',
    weekStart: 27,
    weekEnd: 30,
    summary: 'Omar 家族 startup 出海素材 £1500 (玩家迄今最高客单)。Path A 玩家独立做 Y 姐 capstone。Path B 招第 2 团员。',
    events: [
      {
        id: 'ch6_omar_first',
        week: 28,
        type: 'inbox_task',
        customerId: 'cust_omar',
        title: 'Omar · 家族 startup 出海素材',
        reward: 1500,
        narrative: 'Omar: "我家族这个 sustainability tech startup 要进英国。我想要的不是 traditional ads, 而是 storytelling video + cross-cultural localization。预算 £1500 first deliverable。"',
        flagOnAccept: 'l2u_omar_signed',
      },
      {
        id: 'ch6_easter_capstone',
        week: 29,
        type: 'npc_scene',
        sceneId: 'yjie_easter_capstone',
        narrative: 'Y 姐 group chat (Team) 或 DM (Solo): 上海一对 finance 夫妇蜜月行后 AI 内容包',
      },
      {
        id: 'ch6_team_recruit_second',
        week: 28,
        type: 'team_recruit_window',
        requireFlag: 'link2urPath_team',
        availableMembers: ['team_kenji', 'team_aman', 'team_chloe'],
        narrative: 'Team 路径: 招第 2 团员 (Kenji / Aman / Chloe 三选一)',
      },
    ],
  },

  // ── Ch 7 · W31-W42 · 论文期低维持 + 跨圈 + Paul BBC ──
  {
    chapterId: 'link2ur_ch7',
    title: '论文期低维持',
    weekStart: 31,
    weekEnd: 42,
    summary: '事件密度低但 inbox 持续滴答。Y 姐论文期 cameo。陈一帆推 Whitmore。Paul BBC 采访玩家 — AI 时代身份感悟核心场景。Aman clash。王凯介绍 Eric。',
    events: [
      {
        id: 'ch7_chen_recommends_whitmore',
        week: 33,
        type: 'crossover',
        crossoverId: 'cross_yjie_whitmore_indirect',
        narrative: '陈一帆推荐玩家给 Whitmore。Whitmore office hour: "Heard you\'ve built an AI thing. Make sure it\'s still you doing the thinking."',
      },
      {
        id: 'ch7_y_thesis_checkin',
        week: 36,
        type: 'npc_scene',
        sceneId: 'yjie_thesis_checkin',
        narrative: 'Y 姐凌晨 DM "撑住吖。论文写完你就识乜嘢叫 freedom。"',
      },
      {
        id: 'ch7_paul_bbc_interview',
        week: 38,
        type: 'crossover',
        crossoverId: 'cross_yjie_paul_bbc',
        flagOnComplete: 'l2u_paul_interview_done',
        flagOnComplete2: 'l2u_ai_anxiety_resolved',
        narrative: '🔴 Paul BBC "AI Times: Immigrant Labor in the Age of Algorithms" 专题采访。玩家身份感悟时刻 + 母题反思。',
      },
      {
        id: 'ch7_aman_clash',
        week: 40,
        type: 'mini_arc',
        memberId: 'team_aman',
        phase: 'clash',
        requireFlag: 'l2u_team_recruited_aman',
        narrative: 'Aman: "I make you the most money. £12/h cut needs to be £22." 三选一: 涨 £22 / 折衷 £18 / 不涨',
      },
      {
        id: 'ch7_wangkai_introduces_eric',
        week: 41,
        type: 'crossover',
        crossoverId: 'cross_wangkai_eric_steal',
        requireFlag: 'link2urPath_team',
        narrative: '王凯酒桌介绍 Eric。Eric 可选招入 (替换 Ch 7 常规 slot)',
      },
      {
        id: 'ch7_thesis_period_end',
        week: 42,
        type: 'flag_set',
        flagOnSet: 'l2u_thesis_period_survived',
        narrative: '论文期 low-maintenance 阶段结束',
      },
    ],
  },
  // ── Ch 8 · W45-W47 · Y 姐合并提议 (对撞妈妈电话) ──
  {
    chapterId: 'link2ur_ch8',
    title: 'Y 姐合并提议',
    weekStart: 45,
    weekEnd: 47,
    summary: 'Omar 升级 £30k/年 → Y 姐发现 → Sketch 二访合并提议。妈妈电话同周 W47, 留下做事业 vs 回国稳定的双重 pressure 浓缩。',
    events: [
      {
        id: 'ch8_omar_upgrade',
        week: 45,
        type: 'inbox_task',
        customerId: 'cust_omar',
        title: 'Omar · 家族基金年度 retainer £30k',
        reward: 30000,
        recurring: 'yearly',
        narrative: 'Omar: "We want you on retainer for the family\'s sustainability portfolio. £30k/year. 12 deliverables. Sponsor visa is on the table if you want."',
        flagOnAccept: 'l2u_omar_retainer_signed',
      },
      {
        id: 'ch8_y_merger',
        week: 47,
        type: 'npc_scene',
        sceneId: 'yjie_merger_offer',
        narrative: 'Y 姐 Sketch 二访合并提议: "客户复用 cross-sell" napkin model。三/四选一根据 path。',
      },
      {
        id: 'ch8_mama_call_overlap',
        week: 47,
        type: 'flag_set',
        flagOnSet: 'l2u_mama_call_during_merger',
        narrative: 'Y 姐提议同一天下午, 妈妈打来电话 (主线 W47): "你王阿姨女儿选调上岸了 25w + 户口" — 双重 pressure',
      },
    ],
  },

  // ── Ch 9 · W48-W52 · 终局抉择 + 结局 ──
  {
    chapterId: 'link2ur_ch9',
    title: '终局抉择 + 结局',
    weekStart: 48,
    weekEnd: 52,
    summary: '根据 Ch 8 决定不同走向: 合并 / 独立 Team / Solo。W50 Y 姐 Sketch 再约。W51-52 和主线离别周并行。W52 毕业典礼后结局 walk-down。',
    events: [
      {
        id: 'ch9_post_merger_setup',
        week: 48,
        type: 'flag_set',
        flagOnSet: 'l2u_path_finalized',
        narrative: '合并 path: 起草协议 + 联合署名 LinkU Bespoke + AI Studio / 独立 Team: 品牌升级 6 人团队 / Solo: 成"伦敦最难约的 AI 内容专家"',
      },
      {
        id: 'ch9_y_farewell',
        week: 51,
        weekStart: 51,
        type: 'npc_scene',
        sceneId: 'yjie_farewell',
        narrative: 'Y 姐 RFH 旁咖啡店最后一面 (不同 path 不同对白 + 不同礼物)',
      },
      {
        id: 'ch9_lily_scarf',
        week: 51,
        type: 'flag_set',
        flagOnSet: 'l2u_lily_scarf_packed',
        requireRelationship: { customerId: 'cust_lily', minRelationship: 'fan_unlocked' },
        narrative: '寄箱子时把 Lily 送的 Mulberry 围巾装进去 (跨阶段陪伴 callback)',
      },
      {
        id: 'ch9_ending_walk_down',
        week: 52,
        type: 'ending_resolve',
        narrative: '毕业典礼后结局表 walk-down 触发对应 ending (y_double / link2ur_solo_apex / link2ur_team_founded / Tier 4 兜底)',
      },
    ],
  },
];

export function getActiveChapter(day) {
  const week = Math.ceil(day / 7);
  return (
    LINK2UR_CHAPTERS.find((c) => week >= c.weekStart && week <= c.weekEnd) ||
    LINK2UR_CHAPTERS[0]
  );
}
