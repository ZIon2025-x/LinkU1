// Link2Ur 熟人单 — 接到熟人发的任务，揭面后解锁专属对话。
//
// 设计原则：
// 1. 任务在板上看起来匿名（标题不出现 NPC 名字），player 接单后才发现
//    "啊原来是 Aditi / 林南 / Mark"。这种揭面是叙事张力的核心。
// 2. 触发要求好感度门槛 + flag 门槛，避免一上来就刷出来。
// 3. 每张熟人单游戏内只刷一次（用 link2urFriendsCompleted 列表去重）。
// 4. 接单的金钱/精力/行动结算和普通单一致，但额外打开一个 EventModal
//    带 2-3 个选择，决定 NPC 关系走向。
//
// 数据流：
//   generateBoard(state) 调用 getEligibleFriendTasks(state) 拿到候选
//   ↓ 选 1 张插到板首（如果有）
//   ↓ 玩家点接单 → L2U_ACCEPT_TASK 正常结算 + 标记 link2urFriendsCompleted
//   ↓ App.jsx 检测 task.friendTask → setActiveEvent({ ... task.narrative })
//   ↓ 玩家选 → applyChoice 应用 npc rel + flag

export const LINK2UR_FRIEND_TASKS = [
  // ───────────────────────────────────────────────
  // Aditi · GP 取药 + Senate House 7 楼送达
  // ───────────────────────────────────────────────
  {
    id: 'l2u_friend_aditi_meds',
    npcId: 'aditi',
    templateId: 'l2u_friend_aditi_meds',
    type: 'pickup_dropoff', emoji: '💊',
    // 板上显示
    title: 'GP 取处方药 + 送 Senate House 7F',
    desc: '客户感冒发烧但 deadline 在身。需要去 Bloomsbury Surgery 取药 + 送图书馆 7 楼座位。',
    reward: 22,
    rating: 5,
    energyCost: 6,
    actionCost: 1,
    // 触发条件
    minWeek: 14, maxWeek: 40,
    condition: ({ npcRel, flags }) =>
      (npcRel.aditi || 0) >= 4 && !flags.l2u_friend_aditi_done,
    // 接单后的揭面 narrative
    narrative: {
      title: 'Senate House 7 楼 · 23 号桌',
      body:
        '你拎着 Boots 处方袋上电梯到 7 楼。\n\n' +
        '客户位置纸条上写：「23 号桌 靠窗 戴黑围巾」。\n\n' +
        '你绕过书架——23 号桌的人抬头。\n\n' +
        'Aditi。\n\n' +
        '她也愣住。她戴着黑围巾，鼻子红。眼眶下面有两圈黑。' +
        '面前 4 杯空 Pret 咖啡杯。Word 文档显示 11,400 / 15,000 字。\n\n' +
        '"...Oh." 她小声说。"I didn\'t know it would be you."',
      choices: [
        {
          label: '"Are you ok? You should be in bed."',
          effect: { energy: -2, belonging: 8, npc: { aditi: 3 }, flag: 'l2u_friend_aditi_done' },
          feedback:
            'Aditi 沉默了 3 秒。然后她说："I can\'t. Dad\'s in hospital. ' +
            'I told him I\'d submit by Friday so he can read it before..." 她没说完。\n\n' +
            '你在她对面空椅子上坐下。把药袋放在桌上。\n\n' +
            '你说："Take the meds. Sleep 4 hours. I\'ll watch your laptop."\n\n' +
            '她哭了 30 秒——很安静，怕打扰别人——然后趴在桌上睡着了。\n\n' +
            '你坐到她醒。这一下午什么都没干。但你想：值。',
        },
        {
          label: '默默把药放下 不点破',
          effect: { belonging: 4, npc: { aditi: 1 }, flag: 'l2u_friend_aditi_done' },
          feedback:
            '你把药袋放在桌上，点头退开。\n\n' +
            '她小声说"thank you"。你下楼。\n\n' +
            '当晚她给你发微信："That was kind. ' +
            'I would have been embarrassed if you said anything. Thank you for not."\n\n' +
            '你回："Always."\n\n' +
            '有些朋友是用这种方式建立的——不戳穿。',
        },
        {
          label: '"我请你下楼吃个饭 你必须下班"',
          effect: { energy: -5, belonging: 12, npc: { aditi: 4 }, flag: 'l2u_friend_aditi_done' },
          feedback:
            '你硬把她的 laptop 合上。她抗议："I have a deadline—"\n\n' +
            '你说："Your dad doesn\'t want a thesis. He wants you to be ok."\n\n' +
            '她愣住。然后她哭了——这次不是无声的。你递纸巾。\n\n' +
            '你们下楼去 Pret 楼下的 Wagamama。她吃了一整碗 chicken katsu。\n\n' +
            '吃完她说："I forgot what it\'s like to be looked after."\n\n' +
            '你说："Welcome back."',
        },
      ],
    },
  },

  // ───────────────────────────────────────────────
  // 林南 · 陪同去 senior tutor 谈 module change
  // ───────────────────────────────────────────────
  {
    id: 'l2u_friend_linnan_module',
    npcId: 'linnan',
    templateId: 'l2u_friend_linnan_module',
    type: 'accompany', emoji: '🎓',
    title: '陪同去 senior tutor 谈话',
    desc: '客户社恐，要谈 module change 但不敢一个人去。需要在场陪同 30 min。',
    reward: 25,
    rating: 5,
    energyCost: 4,
    actionCost: 1,
    minWeek: 8, maxWeek: 30,
    condition: ({ npcRel, flags }) =>
      (npcRel.linnan || 0) >= 3 && !flags.l2u_friend_linnan_done,
    narrative: {
      title: 'Faculty Office · 候诊式的走廊',
      body:
        '你按照地址到 Faculty 楼三楼候诊式走廊。\n\n' +
        '客户自报："黑色卫衣 戴口罩 坐最里头那张椅子"。\n\n' +
        '你走过去——抬头的人是林南。\n\n' +
        '他先愣 0.5 秒，然后赶紧低头："...是你啊。"\n\n' +
        '他手里捏着一张已经被汗湿透的 Module Change Request Form。' +
        '上面写要从 Quantitative Finance 转到 Sociology of Migration。\n\n' +
        '"我爸妈不知道。" 他说。"我今天是 sneaking 来谈的。"',
      choices: [
        {
          label: '"你想清楚了 就直接讲 我在旁边"',
          effect: { energy: -3, belonging: 8, academic: 2, npc: { linnan: 3 }, flag: 'l2u_friend_linnan_done' },
          feedback:
            'Senior tutor 是个 60 多岁的英国老头，听完林南磕磕巴巴讲完 5 分钟。\n\n' +
            '他点头："Sociology of Migration is rigorous. You\'ll work harder, not less. ' +
            'You\'re sure?" 林南说"Yes Sir"。\n\n' +
            '老头签字。林南走出办公室手在抖。\n\n' +
            '在楼梯间他跟你说："谢谢你来。我自己一个人 100% 会逃走。"\n\n' +
            '你说："你爸妈早晚要知道。"\n\n' +
            '他说："我知道。但今天先把这关过了。"',
        },
        {
          label: '帮他改了 form 措辞 让他读稿',
          effect: { energy: -5, belonging: 4, npc: { linnan: 2 }, flag: 'l2u_friend_linnan_done' },
          feedback:
            '你拿过 form，把"I want to change"改成"I am requesting consideration of a transfer to..."。\n\n' +
            '林南照着你写的逐字读完。Senior tutor 听完笑了一下："Thoughtful application. Approved."\n\n' +
            '出来林南说："你写的比我自己的版本好太多了。"\n\n' +
            '你说："你下次自己也能写。" 他不太信但点头。\n\n' +
            '这次你帮过头了一点，但救下了一节人生岔口。',
        },
        {
          label: '反劝他"再想想 别冲动"',
          effect: { belonging: -2, npc: { linnan: -2 }, flag: 'l2u_friend_linnan_done' },
          feedback:
            '林南听完你说的话沉默了 30 秒。\n\n' +
            '然后他站起来："...那我先回去想想。" 他没进 office。\n\n' +
            '一周后你在 tutorial 看到他——他还在 Quantitative Finance。\n\n' +
            '他对你笑了一下，但那个笑你看得出来：他没原谅你那天没站他这边。\n\n' +
            '你想：有时候朋友需要的是一句"go for it"，不是"think about it"。',
        },
      ],
    },
  },

  // ───────────────────────────────────────────────
  // Mark · 教我做 Sunday roast 给妈妈过生日
  // ───────────────────────────────────────────────
  {
    id: 'l2u_friend_mark_roast',
    npcId: 'mark',
    templateId: 'l2u_friend_mark_roast',
    type: 'cooking', emoji: '🥩',
    title: '教做 Sunday roast 给妈妈过生日',
    desc: 'Tottenham boy, 22, 第一次想给妈妈做饭。需要一个会做菜的来教 1 小时。',
    reward: 20,
    rating: 5,
    energyCost: 5,
    actionCost: 1,
    minWeek: 12, maxWeek: 30,
    // Mark 必须先道歉过（apology arc 走过），才有这条熟人单
    condition: ({ flags }) =>
      !!flags.mark_apologized && !flags.l2u_friend_mark_done,
    narrative: {
      title: '楼下厨房 · 周日下午',
      body:
        '你按地址下楼——发现客户位置就是你自己 flat 的厨房。\n\n' +
        '推门进去，Mark 站在那里围着围裙，看到你笑出来：' +
        '"Mate. I didn\'t actually know it\'d be you on the app, but... cheers for coming."\n\n' +
        '台子上：一只 1.5kg 的 chicken（不是 turkey 因为他买不起）+ 几个 potatoes + ' +
        '一袋 carrots + 一瓶 gravy granules + Yorkshire pudding 预制粉。\n\n' +
        '"Mum\'s 50 next Sunday. She\'s done a roast every Sunday for 30 years. ' +
        'I want to do one for her. I\'ve never cooked anything that wasn\'t pasta."',
      choices: [
        {
          label: '完整教 + 周日带他去 Sainsbury\'s 选材',
          effect: { energy: -5, belonging: 14, npc: { mark: 4 }, flag: 'l2u_friend_mark_done' },
          feedback:
            '你们花了 3 小时。你教他：怎么 truss the chicken / oven 200°C 50 分钟 / ' +
            'baste 用什么 / Yorkshire pudding 的面糊为什么必须冷 / 怎么调 gravy。\n\n' +
            '他记笔记记到 iPhone Notes 里。每条后面都加 "(don\'t fuck this up)"。\n\n' +
            '周日他真的做了。下周一他敲你的门 —— 手里一盒 Tupperware：\n\n' +
            '"Saved you the leftover. Mum cried, mate. She fucking cried. ' +
            'She told my dad on the phone \'our boy made me a roast\'. He\'s never made her one in 27 years."\n\n' +
            '你打开 Tupperware。chicken 烤老了一点，gravy 太稀。但是它是 Mark 做的。',
        },
        {
          label: '写个详细菜谱让他自己干',
          effect: { energy: -2, belonging: 6, npc: { mark: 2 }, flag: 'l2u_friend_mark_done' },
          feedback:
            '你坐下来在 Notes 上写了一份 800 字 step-by-step 菜谱发给他。\n\n' +
            '周日他独自做。下周一你撞见他："Mate, how was it?"\n\n' +
            'Mark："Burnt the potatoes. Chicken was alright. Mum said it was the best roast of her life. ' +
            'She\'s lying obviously but she meant it."\n\n' +
            '你笑了。这个版本的 Mark 没你陪，但他自己干成了。' +
            '有时候一份菜谱比一个老师重要——因为他得自己 own it。',
        },
        {
          label: '"Mate, just buy a Sainsbury\'s prepped one"',
          effect: { energy: 1, belonging: -3, npc: { mark: -2 }, flag: 'l2u_friend_mark_done' },
          feedback:
            'Mark 看了你 5 秒。然后他说："Yeah. You\'re right. Cheers."\n\n' +
            '他周日真的去 Sainsbury\'s 买了 £15 prepped roast。\n\n' +
            '下周一他没敲你的门。你后来在厨房遇到他——他挺礼貌但没再聊。\n\n' +
            '你想：他不是要省事。他是想给妈妈做一件他亲手的事。\n\n' +
            '你帮他剪了一段不该剪的弧。',
        },
      ],
    },
  },
];

// ──────────────────────────────────────────────────────
// Selection helper
// ──────────────────────────────────────────────────────

/**
 * Filter friend tasks down to those whose conditions are satisfied right now.
 * Excludes tasks already completed (via link2urFriendsCompleted list on state).
 */
export function getEligibleFriendTasks(state) {
  const week = Math.ceil((state.day || 1) / 7);
  const completed = new Set(state.link2urFriendsCompleted || []);
  return LINK2UR_FRIEND_TASKS.filter((t) => {
    if (completed.has(t.id)) return false;
    if (t.minWeek && week < t.minWeek) return false;
    if (t.maxWeek && week > t.maxWeek) return false;
    if (t.condition) {
      const ctx = { flags: state.flags || {}, npcRel: state.npcRel || {}, week };
      if (!t.condition(ctx)) return false;
    }
    return true;
  });
}

/**
 * Pick at most one friend task instance for this week's board, given state.
 * Returns the task (already in spawn-shape, ready to merge into board) or null.
 */
export function pickFriendTaskForBoard(state, rng = Math.random) {
  const eligible = getEligibleFriendTasks(state);
  if (eligible.length === 0) return null;
  const t = eligible[Math.floor(rng() * eligible.length)];
  const week = Math.ceil((state.day || 1) / 7);
  return {
    id: `${t.id}-w${week}`,
    templateId: t.templateId,
    type: t.type,
    emoji: t.emoji,
    title: t.title,
    desc: t.desc,
    reward: t.reward,
    energyCost: t.energyCost,
    actionCost: t.actionCost,
    rating: t.rating,
    week,
    // Markers for the consumer
    friendTask: true,
    npcId: t.npcId,
    narrative: t.narrative,
  };
}
