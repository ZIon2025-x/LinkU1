export const NPC_NETWORK_EVENTS = [
  // ===== 王凯 - Mei 姐 (华人圈) =====
  {
    id: 'wk_introduce_mei',
    title: '王凯帮你引荐 Mei 姐',
    body: '王凯说："哥们 你天天吃 Tesco 也不是个事。我带你去吃个饭。"\n\n你们走进 Mei\'s。王凯一进门就用闽南话和老板娘打招呼。她看了你一眼："你朋友？"\n\n王凯："学弟/学妹 第一年的。"\n\nMei 姐："哎呀真是，进来进来。"',
    location: 'mei',
    condition: ({ npcRel }) => (npcRel.wangkai || 0) >= 4 && (npcRel.mei || 0) <= 1,
    auto: true,
    choices: [
      { label: '认真感谢两个人', effect: { energy: 3, belonging: 8, npc: { wangkai: 2, mei: 3 } },
        feedback: 'Mei 姐多送了你们一道炒青菜。她跟王凯说"这孩子看起来老实"。王凯小声跟你说"Mei 姐人最好了"。你这一顿吃得心里暖暖的。' },
    ],
  },
  {
    id: 'mei_about_wk',
    title: 'Mei 姐说起王凯',
    body: '中餐馆只剩你和 Mei 姐。她擦着桌子，突然说："你那个王学长啊，去年和女朋友分手了，挺可怜的。"\n\n你愣了。你不知道。',
    location: 'mei',
    condition: ({ npcRel }) => (npcRel.wangkai || 0) >= 5 && (npcRel.mei || 0) >= 5,
    choices: [
      { label: '"啊 我都不知道"', effect: { energy: -2, belonging: 4, npc: { mei: 1 } },
        feedback: 'Mei 姐说："他不会跟你说的。男孩子嘛。" 然后她叹了口气。"你要多照顾他点。"\n\n你回去之后看了一晚上王凯的朋友圈。原来去年圣诞他发的"独自一人"不是开玩笑。' },
      { label: '"他没跟我说过"', effect: { belonging: 2, npc: { mei: 0, wangkai: -1 } },
        feedback: 'Mei 姐看了你一眼："那你是他什么朋友？" 这句话有点扎人。\n\n你回去之后给王凯发了"哥 周末一起吃饭吗"。他半天才回："行 你请客啊。"' },
    ],
  },
  {
    id: 'wk_mei_gossip',
    title: '王凯吐槽 Mei 姐',
    body: '王凯一边喝奶茶一边说："Mei 姐昨天又跟我说你的事。她说\'王凯 你别带坏那个孩子\' 哥们你说我是不是坏人。"',
    location: 'soho',
    condition: ({ npcRel }) => (npcRel.wangkai || 0) >= 6 && (npcRel.mei || 0) >= 5,
    choices: [
      { label: '笑着说"她是关心我"', effect: { energy: 3, belonging: 6, npc: { wangkai: 1, mei: 1 } },
        feedback: '王凯笑了："是是是 Mei 姐人最好了。" 然后他叹气："就是我妈不在伦敦，她有点像我妈。" 你愣了一下。原来王凯也有他需要的人。' },
    ],
  },

  // ===== Sarah - Whitmore (学术圈) =====
  {
    id: 'sarah_about_whitmore',
    title: 'Sarah 转述 Whitmore',
    body: 'Sarah 在咖啡店突然说："Oh by the way—Whitmore mentioned you in supervision yesterday. He said you ask the most interesting questions in tutorial."\n\n你愣住。',
    location: 'pub',
    condition: ({ npcRel }) => (npcRel.sarah || 0) >= 5 && (npcRel.whitmore || 0) >= 3,
    choices: [
      { label: '"Really?? I had no idea"', effect: { energy: 8, belonging: 10, academic: 3, npc: { sarah: 1 } },
        feedback: 'Sarah 笑了："He doesn\'t say that about anyone. Trust me." 你回家路上一直在笑。原来你说的话，他真的有听。' },
      { label: '"He\'s just being polite"', effect: { energy: -3, belonging: -5, npc: { sarah: -1 } },
        feedback: 'Sarah 摇头："Trust me, Whitmore is never \'just polite\'." 但你不愿意接受。某种自我保护——如果不相信，就不会失望。' },
    ],
  },
  {
    id: 'whitmore_about_sarah',
    title: 'Whitmore 提起 Sarah',
    body: 'Office hours 结束。Whitmore 一边收拾文件一边说："Sarah tells me you two have been studying together. Good. She\'s a sharp one. You both think differently—that\'s how good ideas happen."',
    location: 'uni',
    condition: ({ npcRel }) => (npcRel.sarah || 0) >= 4 && (npcRel.whitmore || 0) >= 5,
    auto: true,
    choices: [
      { label: '"她帮了我很多"', effect: { energy: 3, academic: 4, belonging: 6, npc: { sarah: 1, whitmore: 1 } },
        feedback: 'Whitmore 点头："Good people are hard to find. Don\'t lose her." 这是你听过他最不"教授"的一句话。' },
    ],
  },

  // ===== Whitmore - Aditi (学术圈) =====
  {
    id: 'whitmore_about_aditi',
    title: 'Whitmore 谈到 Aditi',
    body: '你和 Whitmore 在走廊里走。他突然说："Your friend Aditi—she\'s working too hard. I see her in the library at midnight. Would you... talk to her?"',
    location: 'uni',
    condition: ({ npcRel }) => (npcRel.aditi || 0) >= 4 && (npcRel.whitmore || 0) >= 5,
    choices: [
      { label: '"我会的 教授"', effect: { energy: -3, belonging: 8, npc: { whitmore: 2, aditi: 2 } },
        feedback: '你那晚专门去图书馆找 Aditi。她抬头看到你愣了一下："How did you know I was here?"\n\n你说："Whitmore 让我来的。" 她哭了。她说没想到老师注意到她了。' },
      { label: '"她自己有自己的节奏"', effect: { belonging: -2, npc: { whitmore: -1 } },
        feedback: 'Whitmore 看了你一眼："Hmm." 那个 "Hmm" 持续在你耳边响了一周。' },
    ],
  },

  // ===== Sarah - Aditi (同班但不熟) =====
  {
    id: 'sarah_about_aditi',
    title: 'Sarah 私下问起 Aditi',
    body: 'Sarah 一边喝 G&T 一边说："Hey, you\'re close with Aditi, right? Is she okay? She always looks... exhausted."',
    location: 'pub',
    condition: ({ npcRel }) => (npcRel.sarah || 0) >= 5 && (npcRel.aditi || 0) >= 5,
    choices: [
      { label: '简单说"她最近不容易"', effect: { belonging: 4, npc: { sarah: 1, aditi: -1 } },
        feedback: 'Sarah 点头："Should I... reach out?" 你不知道该说什么。然后你说："Maybe a text would mean a lot." 第二天 Aditi 给你发"Sarah just texted me. That was nice"。' },
      { label: '"这是她的私事 不便说"', effect: { belonging: 6, npc: { sarah: 0, aditi: 3 } },
        feedback: 'Sarah 点头："Of course. Sorry." 你保护了 Aditi。她不知道，但你知道。' },
    ],
  },
  {
    id: 'three_lunch',
    title: '三人午餐',
    body: '你提议 Sarah 和 Aditi 一起吃午餐。她们以前没真正说过话。\n\n气氛一开始有点尴尬。Sarah 太外向，Aditi 太安静。',
    location: 'uni',
    condition: ({ npcRel }) => (npcRel.sarah || 0) >= 6 && (npcRel.aditi || 0) >= 6,
    choices: [
      { label: '主动当桥梁，让她们都自在', effect: { energy: -8, belonging: 15, npc: { sarah: 2, aditi: 2 } },
        feedback: '半小时后她们已经在讨论各自国家的婚礼传统。1 小时后 Sarah 大笑出声，Aditi 也罕见地放声笑。\n\n离开时 Aditi 跟你说："I\'ve never had two friends from completely different worlds. Thank you." 你愣了一下。原来朋友圈是可以建造的。' },
      { label: '让她们自己处理 不插嘴', effect: { energy: -5, belonging: 5 },
        feedback: '她们尴尬地聊完了 30 分钟然后各自走了。Aditi 后来跟你说"Sarah seems nice"，Sarah 跟你说"Aditi is... interesting"。但你能感觉到，她们不会再约第二次了。' },
    ],
  },

  // ===== 跨圈 (王凯 vs Sarah) =====
  {
    id: 'wk_meets_sarah',
    title: '王凯遇到 Sarah',
    body: '你和 Sarah 在 Pub。王凯刚好路过来打招呼：「哥们 这位是？」你介绍。\n\nSarah 用 BBC 口音的英语说"Lovely to meet you"。王凯也用英语回："Yeah... cool, cool."\n\n气氛凝固了 5 秒。',
    location: 'pub',
    condition: ({ npcRel }) => (npcRel.wangkai || 0) >= 6 && (npcRel.sarah || 0) >= 6,
    choices: [
      { label: '帮忙打圆场', effect: { energy: -5, belonging: 8, npc: { wangkai: 1, sarah: 1 } },
        feedback: '王凯走后 Sarah 说："He seems... cool." 第二天王凯给你发微信："哥们你那个金发朋友 行 你混得不错。" 你哭笑不得。两个世界第一次碰头。' },
    ],
  },
];


export const NPCS = {
  sarah: {
    id: 'sarah', name: 'Sarah', cn: '莎拉', avatar: 'S', color: '#d4a574',
    role: '英国本地同学',
    bio: '金发，喜欢喝 G&T。本科直升研究生。偶尔会问你一些"傻"问题。',
    locations: ['uni', 'pub', 'library'],
  },
  wangkai: {
    id: 'wangkai', name: '王凯', cn: '王凯', avatar: '凯', color: '#c4615a',
    role: '中国学长',
    bio: 'PhD 第二年，消息灵通，会带你薅羊毛。',
    locations: ['mei', 'uni', 'soho'],
  },
  aditi: {
    id: 'aditi', name: 'Aditi', cn: '阿迪缇', avatar: 'A', color: '#a87fb8',
    role: '印度同学',
    bio: '每天图书馆最后一个走。她爸爸最近生病了。',
    locations: ['library', 'uni'],
  },
  whitmore: {
    id: 'whitmore', name: 'Prof. Whitmore', cn: '惠特摩尔教授', avatar: 'W', color: '#7a8a6a',
    role: '你的导师',
    bio: '60多岁，永远穿花呢西装，话里有话。',
    locations: ['uni'],
  },
  mei: {
    id: 'mei', name: 'Mei', cn: 'Mei 姐', avatar: '梅', color: '#b85070',
    role: '中餐馆老板娘',
    bio: '福建人，30年前来的伦敦。骂你的时候是真心疼你。',
    locations: ['mei'],
  },
  linnan: {
    id: 'linnan', name: 'Lin', cn: '林可儿 / 林楠', avatar: '林', color: '#a07090',
    role: '同班同学（中国）',
    bio: '本科金融转社会学。爸妈不太理解。每节 tutorial 坐第一排但不太说话。',
    locations: ['library', 'uni', 'soho'],
  },
};
