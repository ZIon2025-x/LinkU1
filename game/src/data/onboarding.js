// Day-0 onboarding flow: plane scene → Heathrow → transport choice.
//
// The plane scene is a single narrative beat with one button.
// The transport step branches the start of week 1 — your wallet & energy
// going into orientation are set by which option you pick.

export const PLANE_SCENE = {
  title: '机舱',
  subtitle: 'Day 0 · 飞往伦敦',
  body: [
    '11 个小时。你已经在云上 9 个小时了。',
    '空姐刚收走餐盘，舱内灯调暗。隔壁是个英国老太太，从北京一路睡过来。',
    '你看着小屏幕上的航迹图——蓝色的飞机正在掠过黑海。还有 90 分钟落地。',
    '你低头看自己手里的护照。CAS 信夹在里面，边角已经被汗手摸得发软。',
    '行李托运了两个 28 寸箱子。妈妈在浦东送你时塞了一袋老干妈，你硬是没让她哭。',
    '你不知道你即将开始的这一年是什么样子。但你知道——它从这一刻开始算。',
  ],
  cta: '把窗帘拉开看看',
};

export const HEATHROW_INTRO = {
  title: 'Heathrow T3',
  subtitle: '到了',
  body: [
    '飞机降落时英国老太太拍了拍你手背："Welcome, dear."',
    '入关排了 40 分钟。海关问你 "What are you here to study?" 你回答之后他点点头盖章。',
    '行李转盘上你的两个箱子是最后出来的——你以为它们丢了，差点哭出来。',
    '你推着行李车走出 Arrivals。伦敦时间下午 4 点。外面下着小雨。',
    '你已经 22 小时没合眼。下一步，去你的公寓。',
  ],
};

// Each option modifies starting state. `wallet` is subtracted (negative) and
// `energy` is added/subtracted. `time` is just flavor.
export const TRANSPORT_OPTIONS = [
  {
    id: 'tube',
    emoji: '🚇',
    label: '地铁 (Piccadilly Line)',
    cost: 6,
    energyDelta: -15,
    time: '90 分钟 · 4 次换乘',
    desc: '最便宜，但你要拖两个 28 寸箱子在 Piccadilly 线挤地铁。',
    feedback: '你在 Earl\'s Court 换车时一个箱子翻倒，挡住了一整条通道。一个老外帮你扶起来，没说话，没看你，就走了。\n\n你到公寓时浑身是汗，肩膀酸得抬不起来。但你存下了 £69——足够你下个月吃 7 顿好的。',
  },
  {
    id: 'express',
    emoji: '🚆',
    label: 'Heathrow Express + Tube',
    cost: 28,
    energyDelta: -5,
    time: '50 分钟 · 1 次换乘',
    desc: 'T3→Paddington 15 分钟直达，再换 Tube 到公寓。',
    feedback: 'Heathrow Express 干净、安静、贵。15 分钟到 Paddington 时你眯了一会眼。\n\n下了车你就开始累——伦敦地铁老到没电梯。但比起拖箱子全程地铁，这 £28 你愿意。',
  },
  {
    id: 'cab',
    emoji: '🚖',
    label: '黑色出租车 (Black Cab)',
    cost: 75,
    energyDelta: 5,
    time: '60 分钟 · 门到门',
    desc: '直接到公寓楼下。司机会跟你聊天，可能讲整路伦敦冷笑话。',
    feedback: '司机问你 "First time?" 你点头。他说 "Don\'t worry, you\'ll figure it out, love."\n\n这一路是这一年里你最舒服的一段路。但 £75。这笔钱你心疼了三天。',
  },
];

// Initial state values for new game (used by reducer/initialState).
//
// Realistic UK MSc student finance: parents wired £9.2k (annual rent £8k +
// £1.2k buffer) before the kid flies. Rent goes straight to the letting agent.
// What lands in the kid's actual UK bank account is the £1.2k buffer.
// Monthly stipend tops up living costs through the year.
//
// 经济压力调校 (v11.1)：原 £2000 太宽裕,玩家可以整个 chapter 1 不开 Link2Ur 也撑得过去。
// 改成 £1200 让 W1-W4 第一笔 stipend 之前必须主动接 1-2 单 Link2Ur 才不会见底。
export const STARTING_WALLET = 1200;
export const STARTING_ACADEMIC = 0;

// Annual rent shown in narrative only — not deducted from the player's wallet
// because parents paid the agent directly before the game starts.
export const ANNUAL_RENT_DISPLAY = 8000;

// Monthly stipend deposit — every 4 weeks, on the first day of a "month".
// Months align with weeks: 1-4, 5-8, 9-12, ...
// The first deposit fires when entering week 5 (after the first month at the
// initial wallet).
export const MONTHLY_STIPEND = 500;
export const STIPEND_INTERVAL_WEEKS = 4;

export function isStipendWeek(week) {
  return week > 1 && (week - 1) % STIPEND_INTERVAL_WEEKS === 0;
}

// Apartment arrival — shown after transport choice. This is the moment where
// the financial reality lands: rent is gone, what's left is what you live on.
export const APARTMENT_ARRIVAL = {
  title: '公寓门口',
  subtitle: 'Day 0 · 你的伦敦小屋',
  body: [
    '你拖着箱子上 3 楼。锁孔卡了两次才打开。',
    '留学生公寓 ensuite——一间 11 平米的单人卧室带独立卫浴。厨房和 5 个 housemate 共用，在走廊尽头。',
    '中介在客厅等你。"你爸妈昨天给我转过来了——全年房租 £8,000 已经收讫。水电煤气网都包了，wifi 密码贴在冰箱上。这是合同副本。" 他递过一个牛皮纸文件夹就走了。',
    '你坐在床边打开手机银行。',
    '卡里 £1,200。这就是你这一年除了房租之外的全部启动金——吃饭、地铁、社交、买书、机票。',
    '妈每个月会给你转 £500 补贴。下一笔下个月头到——这一个月你得自己撑过去。其它的，要么自己挣，要么省。',
  ],
  cta: '开始第 1 周 →',
};
