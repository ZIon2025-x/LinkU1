// 节日 · 社交弧线设计：
//
//   早期 (W2 中秋 / W6 万圣 / W8 Diwali)：默认 solo / CSSA 学联活动 /
//     室友 Tom 或 Sarah 路过随口给一句小祝福。还没有朋友。
//
//   中期 (W15 NYE / W17 Burns / W18 春节 / W19 情人 / W21 Pancake / W23 母亲)：
//     室友互动是默认。CSSA 活动仍是 fallback。如果玩家和某个 NPC rel >= 4，
//     额外解锁"和朋友一起"分支（饭桌 / 包饺子 / 一起 march）。
//
//   晚期 (W27 清明 / W38 Trooping / W40 Pride / W44 Carnival)：
//     默认 solo / dissertation。和 NPC rel >= 5 解锁深度合体选项
//     （Sarah 家人带你看 Trooping、和 Aditi 一起 march Pride）。
//
//  Choice 上的 `condition: (s) => boolean` 会被 App.jsx 过滤——
//  没条件的选项始终显示，保证玩家不会被卡住。

export const FESTIVALS = {
  2: { id: 'mid_autumn', cn: '中秋节', emoji: '🥮', desc: '你妈视频里给你看月饼' },
  6: { id: 'halloween', cn: '万圣节', emoji: '🎃', desc: '英国人在装鬼' },
  8: { id: 'diwali', cn: 'Diwali', emoji: '🪔', desc: '全城点灯 / Trafalgar 有 Diwali on the Square' },
  15: { id: 'nye', cn: '跨年夜', emoji: '🎆', desc: 'Trafalgar 烟花 / 北京已是初一' },
  17: { id: 'burns_night', cn: 'Burns Night', emoji: '🥃', desc: '苏格兰人在念诗 / Tom 想做 haggis' },
  18: { id: 'spring_festival', cn: '春节', emoji: '🧧', desc: '微信群在抢红包' },
  19: { id: 'valentines', cn: '情人节', emoji: '💝', desc: '伦敦到处是玫瑰' },
  21: { id: 'pancake_day', cn: 'Pancake Day', emoji: '🥞', desc: '全英国都在抛 pancake' },
  23: { id: 'mothers_day', cn: '英国母亲节', emoji: '💐', desc: '你妈不知道这天' },
  27: { id: 'qingming', cn: '清明节', emoji: '🕯️', desc: '你扫不了的墓' },
  38: { id: 'kings_birthday', cn: 'Trooping the Colour', emoji: '🎖️', desc: 'Mall 上有皇家骑兵' },
  40: { id: 'pride', cn: 'Pride London', emoji: '🏳️‍🌈', desc: 'Soho 全城彩虹' },
  44: { id: 'notting_hill', cn: 'Notting Hill 嘉年华', emoji: '🎉', desc: '加勒比节日' },
};

// 任意 NPC 关系达到阈值（用于"有朋友了"分支判断）
const anyRel = (npcRel, threshold) =>
  Object.values(npcRel || {}).some(v => (v || 0) >= threshold);

export const FESTIVAL_EVENTS = {
  // ─────────────────────────────────────────────────────────────
  // W2 中秋 · 你才到伦敦 2 周。还没有朋友。
  // ─────────────────────────────────────────────────────────────
  mid_autumn: {
    title: '中秋节', emoji: '🥮',
    body: '伦敦时间晚 7 点。北京已经过了零点。\n\n妈视频电话过来——背景是家里的圆桌，月饼礼盒摆在中间。她举起一块给你看："五仁的，你爸非要买。"\n\n你今晚才意识到——这是你 22 年来第一次没在家过中秋。窗外伦敦的月亮有点雾，看不清楚。\n\n你刚到伦敦 2 周。还不太认识谁。',
    choices: [
      { label: '去 CSSA 学联的中秋月饼会', effect: { wallet: -3, energy: 5, belonging: 12, flag: 'cssa' },
        feedback: 'Bloomsbury 一个学校借出来的小活动室。30 多个中国学生，一桌一桌挤着吃月饼、喝桂花茶、看 CSSA 部长用 PPT 念《水调歌头》。\n\n你旁边坐了一个上海男生（凯泽，PhD 一年级）和一个广州女生（@Lily）。3 个小时下来你加了 8 个微信。回去路上你想：原来"留学第一次过节"不一定要自己扛——学联就是给这一刻准备的。\n\n（CSSA 群解锁。）' },
      { label: '去 Loon Fung 买一块月饼 + 一个人吃', effect: { wallet: -8, energy: 3, belonging: 4 },
        feedback: '你坐 73 路去 Chinatown。Loon Fung 货架上摆了 6 种月饼——蛋黄莲蓉 £3.50 一块。\n\n你买了一块带回 ensuite，切成四瓣，吃一瓣，剩下三瓣放冰箱。第二天早上发现冰箱里那瓣不见了——大概是 Tom。你笑了一下。\n\n你给妈发："今晚我也吃月饼了。" 她回了一个月亮 emoji。' },
      { label: 'Tom 路过厨房 + 你给他半块月饼', effect: { energy: 4, belonging: 8 },
        feedback: 'Tom 端着泡面进厨房。看到你桌上那块切开的圆饼："Mate, what\'s that, like a pie?"\n\n你说："Mooncake. Chinese, kinda like — Halloween for the moon? Today\'s our festival."\n\nTom 愣了 1 秒："Oh shit nice. Happy moon day mate." 然后非常严肃地接过半块咬了一口——表情扭曲了 0.5 秒。"It\'s... interesting. Happy whatever-this-is to you." 他举着泡面跟你碰了一下。\n\n你笑了 5 秒。他连节日叫什么都没记住。但他记得跟你碰一下。这种小温暖在伦敦比月饼难得。' },
      { label: '今晚没什么节日氛围 算了', effect: { energy: 0, belonging: -5 },
        feedback: '你刷了一晚上小红书"伦敦留学生中秋怎么过"。看到一个学姐发"今年我在 ensuite 给自己泡了壶花茶 月亮真的圆"。\n\n你抬头看了一眼窗外——伦敦今晚有云。\n\n你关了灯。' },
    ],
  },

  // ─────────────────────────────────────────────────────────────
  // W6 万圣 · 室友是默认。CSSA 是 fallback。朋友 rel>=3 解锁一群一起。
  // ─────────────────────────────────────────────────────────────
  halloween: {
    title: '万圣节夜', emoji: '🎃',
    body: '宿舍楼里所有英国人都装扮起来了。Sarah 是个吸血鬼，Tom 是 Joker。你穿着一件普通的卫衣，站在门口。',
    choices: [
      { label: '跟着 Sarah 和 Tom 去 Student Union', effect: { energy: -8, belonging: 8, wallet: -15 },
        feedback: '你 £15 在 Tesco 买了个塑料面具，跟着他们去了 student union 的 Halloween party。你跳得不太好，但你没逃跑。这个进步比想象中大。' },
      { label: '跟一群朋友约去 Shoreditch club', effect: { energy: -12, belonging: 14, wallet: -30 },
        condition: ({ npcRel }) => anyRel(npcRel, 3),
        feedback: '你和 3 个朋友约在 Shoreditch 一家叫 XOYO 的 club（之前 Cargo 在 2018 年就关掉了，你查了一下才知道）。门口排队 40 分钟。\n\n里面音箱大得能震断耳蜗。你们 4 个跳到凌晨 2 点——其中一个朋友把假血涂到你脸上你也没擦。\n\n回家 Uber Pool £15。你瘫在后座笑出声："我这辈子没这么 chaotic 过。" 你旁边那个朋友说："That\'s the point."' },
      { label: '去 CSSA 留学生 Halloween 派对', effect: { energy: -5, belonging: 6, wallet: -10, flag: 'cssa' },
        feedback: '一个学校借出来的小活动室。20 多个中国学生，没人穿吓人的——大家都穿了"中式恐怖"（一个穿红裙的女生说自己是聂小倩）。你们包了饺子煮汤圆，看了一部老港片《阴阳路》。\n\n这不是真正的伦敦万圣，但对刚到伦敦 6 周的你，刚好够。' },
      { label: '说"我不太懂这个节日" 推掉', effect: { energy: 3, belonging: -6 },
        feedback: '你回房间看了一晚上视频。窗外尖叫声、笑声不断。你想，再过 10 年，你会后悔今晚吗？大概会。' },
    ],
  },

  // ─────────────────────────────────────────────────────────────
  // W8 Diwali · 早期，玩家可能跟 Aditi 还不熟。Aditi 邀请 = 高 rel 才有。
  // ─────────────────────────────────────────────────────────────
  diwali: {
    title: 'Diwali · 排灯节', emoji: '🪔',
    body: '11 月初。Trafalgar Square 今晚有 Diwali on the Square——免费舞台，全城印度社区出动。\n\n你刷 IG 看到 Aditi（你 lecture 上同班那个印度女生）发了一张她家阳台的照片——一排小油灯。配文："Wish I was home tonight."\n\n下午 6 点，Sarah 探头到你 ensuite："Hey we\'re doing dinner — Tom\'s making something he calls curry — wanna join? Btw it\'s Diwali isn\'t it? You should know more about it than us."',
    choices: [
      { label: 'Aditi 私聊邀你去她家小聚 + 真去', effect: { energy: 5, belonging: 14, wallet: -12, npc: { aditi: 3 }, flag: 'diwali_aditi' },
        condition: ({ npcRel }) => (npcRel.aditi || 0) >= 3,
        feedback: 'Aditi 单独私聊你："Small Diwali thing at mine tomorrow. Just sweets, lights, maybe Bollywood. You\'ll be the only non-Indian — sorry in advance for the auntie energy."\n\n你买了一盒 M&S 巧克力（£12，她后来说太多了）。她家厨房挤了 6 个印度女生 + 你，每个人都给你递东西："Try this." "And this." "Oh god this one\'s spicy."\n\n你学会了一个词 — *Shubh Diwali*。你说出来时全屋哄笑（你音节有点不对），然后 Aditi 说"Almost"，又教了三遍。\n\n你看着她笑的样子想：原来 belonging 不一定要在自己的文化里发生。' },
      { label: '一个人去 Trafalgar Square 看灯 + 凑热闹', effect: { energy: -3, wallet: -5, belonging: 8 },
        feedback: '免费舞台 + 全场印度家庭。一个穿莎丽的小女孩塞给你一颗 ladoo："Take, take!" 她妈妈在旁边笑着说"Happy Diwali!"\n\n你站在人群里吃那块甜得过分的糖。伦敦今晚是另一个伦敦——你以为只属于你 cohort 那几张白脸的城市，今晚突然全是印度家庭、孩子、奶奶。\n\n你回宿舍路上经过一户人家——窗台上摆了 12 盏 diya，整条街最亮的就是它。' },
      { label: 'Tom + Sarah 让你给他们解释 Diwali', effect: { energy: 3, belonging: 10 },
        feedback: '你坐在共用厨房，Tom 端着他自己做的"咖喱"（你不忍心看），Sarah 切番茄。\n\n你 Google 了 5 分钟然后照本宣科："It\'s Hindu New Year-ish. Light wins over darkness. People put oil lamps everywhere. And eat way too much sugar."\n\nSarah 听得很认真："That\'s lovely. Should we light a candle? Like solidarity?"\n\n你们三个在厨房点了一支宜家味儿的香薰蜡烛。Tom 说："Happy Diwali to all who Diwali." Sarah 翻了个白眼但也笑了。\n\n你今晚没去任何派对。但你给两个英国人讲了一个不属于他们的节日，他们认真听了。这是你来伦敦第一次有"我也能 share something"的感觉。' },
      { label: '一群朋友约一起 Trafalgar 看灯 + 吃印度菜', effect: { energy: -5, belonging: 16, wallet: -18 },
        condition: ({ npcRel }) => anyRel(npcRel, 4),
        feedback: '你叫了 3 个朋友。Trafalgar Square 看完 fireworks 你们走去 Brick Lane 一家叫 Dishoom 的印度馆——队伍 50 分钟，但你们边排边聊。\n\n吃到一半其中一个朋友突然说："This is the most international moment I\'ve had this year." 大家都笑了。\n\n回去路上 Aditi（如果在场）轻声说："Thanks for thinking of me today." 你说："Thanks for being the reason I noticed this festival exists."' },
      { label: '今晚没什么感觉 自己写 essay', effect: { energy: -2, academic: 3, belonging: -3 },
        feedback: '你戴耳机写 essay。\n\n但你也意识到——你刚错过了一个本可以在 Trafalgar 跟 30 万陌生人一起感受节日的夜晚。\n\n下次。下次你想去看看。' },
    ],
  },

  // ─────────────────────────────────────────────────────────────
  // W15 跨年 · 中后期。CSSA / 室友 / 朋友 / 一个人 全部展开。
  // ─────────────────────────────────────────────────────────────
  nye: {
    title: '跨年夜 · 12 月 31 日', emoji: '🎆',
    body: '伦敦时间晚 11 点。你的微信群已经在抢红包了——北京时间已经是 1 月 1 日早 7 点。\n\n你站在 ensuite 窗前，能听到远处 South Bank 的烟花在试响。Sarah 的房间空着（去 Cotswolds 了）。Tom 大概率在 Manchester。整个宿舍楼今晚只剩几个国际生。\n\n手机上 3 条消息：CSSA 群在约人去 Trafalgar Square，妈视频请求挂着 17 秒没接，林楠（如果你在线）发了一条"在哪？"。',
    choices: [
      { label: '挤地铁去 Trafalgar Square 看烟花', effect: { energy: -8, wallet: -8, belonging: 10, flag: 'nye_trafalgar' },
        feedback: 'Northern line 挤得离谱。你跟人潮走到 Charing Cross，被警察把人流分成 3 个口袋。烟花起来的那一瞬间——London Eye 整个亮起来——你旁边一个澳洲女生抱了你一下："HAPPY NEW YEAR!" 然后转身抱另一个陌生人。\n\n你走回家走了 2 小时（地铁停运）。脚冻得没知觉。但你笑着回的家。\n\n这一刻你不在某个 group chat 里——你在伦敦。' },
      { label: 'CSSA 群约一群人 South Bank 凑热闹', effect: { energy: -8, wallet: -10, belonging: 14, flag: 'cssa' },
        feedback: '你们 8 个人（凯泽、@Lily、新生小王、还有几个名字你刚记住）在 Embankment 桥上挤了 1 小时。零下 2 度，每个人都买了 £5 的热红酒抱在手里。\n\n12 点烟花从 London Eye 周围炸开——大家一起喊"3, 2, 1"——但凯泽喊错了节拍，提前喊了 0，他自己尴尬笑了 30 秒。\n\n回去地铁挤到凌晨 3 点。你睡前发了一条朋友圈：4 个人合照。妈点了赞。' },
      { label: '约一个朋友一起跨年', effect: { energy: -3, belonging: 14, wallet: -15, flag: 'nye_with_npc' },
        condition: ({ npcRel }) => anyRel(npcRel, 5),
        feedback: '你给关系最好的人发了"在哪？"。\n\n10 分钟后你们在 Embankment 桥上汇合。冷得说话都冒白气。烟花起来时你们都没拍照——就站着看。\n\n一年前你不认识这个人。一年后你们一起跨了年。原来这就是一段友谊 / 关系长成的速度。' },
      { label: '宿舍剩下的几个国际生一起做火锅', effect: { energy: 5, belonging: 16, wallet: -22, flag: 'nye_hotpot' },
        condition: ({ flags }) => !!flags.cssa,
        feedback: '你和宿舍里另外 3 个没回家的（一个泰国男生、一个意大利女生、一个尼日利亚男生）凑了 £20 一人去 Loon Fung 买了火锅底料、肥牛卷、虾滑、午餐肉。\n\n共用厨房的 IH 不够热——汤煮了 40 分钟才开。但煮开之后大家都疯了——意大利女生从来没见过虾滑，泰国男生加了 fish sauce，你和尼日利亚男生在抢最后一块肉。\n\n12 点 BBC One 直播 Big Ben 在客厅电视上敲响。你们 4 个举着可乐罐碰了一下："Happy New Year." 没人哭。但每个人都笑得很安静。\n\n这一年你不在家，但你也不孤独。' },
      { label: '给爸妈视频 1 小时', effect: { energy: 3, belonging: 18 },
        feedback: '妈刚醒，头发还乱着。爸在背景里给爷爷拜年。你说"妈新年好"——她哭了 3 秒，又笑了："你那边几点？"\n\n12 点烟花在你窗外炸开的时候你把手机举高给她看："听到了吗？"\n\n她说："好响。" 然后两个人都没说话，就一起听。' },
      { label: '在 ensuite 倒一杯热水 看烟花直播', effect: { energy: 5, belonging: -3 },
        feedback: '你窝在被子里开 BBC One 看 fireworks live。Big Ben 敲 12 下的时候你跟着倒数到 0。\n\n你给自己拍了一张照——卫衣 + 热水杯 + 屏幕里的烟花。你把它存进相册，没发任何朋友圈。\n\n这一晚也算过完了。但只有你自己知道。' },
    ],
  },

  // ─────────────────────────────────────────────────────────────
  // W17 Burns Night · 室友 Tom 是默认（他天然 push 这个节日）。
  // ─────────────────────────────────────────────────────────────
  burns_night: {
    title: 'Burns Night · 1 月 25 日', emoji: '🥃',
    body: '1 月 25 日是 Robert Burns 诞辰——苏格兰人的国民诗人节。\n\n下午 6 点，Tom 在共用厨房煮一锅看起来很可怕的东西："Mate, ever had haggis? It\'s sheep stomach. Don\'t Google it. Just try it." 旁边摆了 mashed neeps + tatties + 一瓶 Whisky。\n\nSarah 探头："He does this every year. It\'s genuinely awful but you should try it once."',
    choices: [
      { label: '坐下试一口 + 听 Tom 念 Burns 诗', effect: { energy: 3, belonging: 10, npc: { sarah: 1 }, flag: 'burns_night_in' },
        feedback: '你尝了一口——出乎意料没那么糟（像加重了胡椒的肉糜）。Tom 从手机上读了一首"Address to a Haggis"，故意把苏格兰口音夸张到极致。Sarah 一边笑一边纠正他发音。\n\n你听不懂 60% 的词。但当 Tom 念到 "Great chieftain o\' the puddin-race" 时整个厨房都笑了，你也笑了——因为他们的笑是真的。\n\n你不需要懂每个字，才能跟一个文化产生关系。' },
      { label: '邀几个朋友一起去 Soho 的苏格兰 pub 凑热闹', effect: { energy: -8, belonging: 14, wallet: -25 },
        condition: ({ npcRel }) => anyRel(npcRel, 4),
        feedback: '你和 2 个朋友在 Soho 一家叫 Boisdale 的苏格兰主题 pub 订了位。一个真的穿 kilt 的乐手在拉风笛。每桌都摆了一小盘 haggis。\n\n你尝了一口 Whisky——直接呛到流眼泪。一个朋友笑得趴在桌上："Mate that was supposed to be sipped." 风笛手转过来朝你举杯。\n\n回家路上你们三个在 tube 上互相用蹩脚苏格兰口音念诗。整车厢英国人都在憋笑。' },
      { label: '"Smells like ass mate" + 礼貌跑路', effect: { energy: 0, belonging: 0 },
        feedback: 'Tom 大笑："Fair enough! More for me." Sarah 给你递了个 Tunnock\'s 茶饼："Have this instead. It\'s also Scottish, less terrifying."\n\n你回 ensuite 啃茶饼。倒也没有 miss out 多少——但你想下次再有 weird local 文化时可以更勇敢一点。' },
      { label: '图书馆赶 essay', effect: { energy: -3, academic: 4, belonging: -2 },
        feedback: '你戴上耳机走出宿舍。厨房里苏格兰口音的诗朗诵跟着你下楼。\n\n你写完了 essay 第三段。\n\n但 1 年后你想起伦敦留学，记得的不是这段 essay——是那晚 Tom 的胡话。' },
    ],
  },

  // ─────────────────────────────────────────────────────────────
  // W18 春节 · CSSA / 一群朋友包饺子 / 一个人外卖。
  // ─────────────────────────────────────────────────────────────
  spring_festival: {
    title: '大年三十', emoji: '🧧',
    body: '伦敦时间下午 4 点。北京时间凌晨 12 点。微信群里在抢红包，你妈在视频里给你看年夜饭。',
    choices: [
      { label: '点一份外卖 + 一个人看春晚', effect: { wallet: -25, energy: 6, belonging: 4 },
        feedback: '£25 的中餐外卖。味道不太对。但你打开淘宝直播看春晚。这就是你第一次在国外的春节。' },
      { label: '去 CSSA 学联包的春节 gala', effect: { wallet: -15, energy: 5, belonging: 12, flag: 'cssa' },
        feedback: '学校 great hall 借出来的春节 gala。300 个中国学生 + 几个慕名而来的英国教授（包括 Whitmore——你看到他了）。\n\n台上节目很尴尬：一个本科男生唱跑调的《我和我的祖国》、一个学姐弹古筝。但 belonging 不在节目质量——belonging 在抬头能看到 300 张同样想家的脸。\n\n散场你领了一个红包（学联发的）：里面是一张 £5 的 Sainsbury\'s voucher。你笑了 1 分钟。' },
      { label: '约几个朋友一起包饺子', effect: { wallet: -40, energy: 10, belonging: 18 },
        condition: ({ npcRel }) => anyRel(npcRel, 4),
        feedback: '你们 5 个人在某个人家里包饺子。皮厚馅少，但这是你们的春节。\n\n王凯（如果在场）从他奶茶店带了 4 杯 free 的奶茶，凯泽（如果在场）带了茅台，Aditi（如果在场）听不懂但也跟着包了一个长得像 samosa 的饺子，大家笑了 5 分钟。\n\n结束后你走在伦敦街上，第一次觉得这里没那么外国。' },
      { label: '约 Mei 姐去她店里一起守岁', effect: { wallet: -20, energy: 8, belonging: 20, npc: { mei: 2 } },
        condition: ({ npcRel }) => (npcRel.mei || 0) >= 5,
        feedback: 'Mei 姐说："傻孩子 没回国就来店里 我留了一桌。"\n\n你到的时候店里关门挂了"私人聚餐"的牌子——里面是 4 个人：Mei 姐 + 她老公（你头一次见 一个沉默的福建男人）+ 另一个学生（也没回国）+ 你。她炒了 5 个家常菜，最贵的是一份酱油焖鸭。\n\n12 点（伦敦时间——Mei 姐坚持要按伦敦不按北京）她举杯："过年好。我们这桌不是亲人 但今晚就是。"\n\n她老公第一次开口："Mei 跟我说过你。多吃。" 然后又埋头吃。\n\n你看着她说话的样子想哭——但你没哭。你举杯，喝了一口她泡的浸了三年的白酒。\n\n这一年最难忘的春节。' },
    ],
  },

  // ─────────────────────────────────────────────────────────────
  // W19 情人节 · 朋友饭桌选项需 rel >= 4 解锁。
  // ─────────────────────────────────────────────────────────────
  valentines: {
    title: '2 月 14 日', emoji: '💝',
    body: 'Pret 把咖啡杯换成红色的。地铁里的情侣比平时多三倍。你刷着小红书，全是"我男朋友 / 女朋友送的礼物"。',
    choices: [
      { label: '给自己买一束花', effect: { wallet: -15, energy: 5, belonging: 4 },
        feedback: '£15 从 Sainsbury\'s 买的。粉色玫瑰加满天星。你回家把它们插进一个 Tesco Meal Deal 的塑料瓶里。然后看着它们笑了。' },
      { label: '去图书馆假装没事', effect: { energy: -5, academic: 3, belonging: -3 },
        feedback: '图书馆里跟你一样的人比平时多。某种说不出来的、单身留学生的隐秘同盟。' },
      { label: '约朋友一起吃 "Forever Alone Party"', effect: { energy: 3, wallet: -25, belonging: 12 },
        condition: ({ npcRel }) => anyRel(npcRel, 4),
        feedback: '你们三个/四个在中餐馆挤一桌。"Forever alone party!" Aditi 举杯。你笑出声。这是你今年最好的 Valentine\'s。' },
      { label: '跟 partner 在 Borough Market 吃晚饭', effect: { energy: 8, wallet: -50, belonging: 15, npc: { linnan: 2 } },
        condition: ({ flags }) => !!flags.linnan_dating,
        feedback: 'Borough Market 一家小法餐店——林可儿 / 林楠提前订了。两份 set menu £45 一人。\n\n上 main course 时林可儿 / 林楠从口袋里掏出一个小盒子——是一根普通的钥匙。"我钥匙复制了一份。下学期你想随时来 ta 房间不用 buzzer。"\n\n你拿着那把铜钥匙，手心出了汗。这不是订婚，但比一束玫瑰更重。' },
    ],
  },

  // ─────────────────────────────────────────────────────────────
  // W21 Pancake Day · Sarah 是宿舍的天然组织者。一群朋友一起 = rel >= 4。
  // ─────────────────────────────────────────────────────────────
  pancake_day: {
    title: 'Pancake Day · Shrove Tuesday', emoji: '🥞',
    body: '周二下午。Sarah 把你拉进厨房："It\'s Pancake Day. We\'re flipping. You\'re joining."\n\n台面上摆了：面粉、鸡蛋、牛奶、一瓶柠檬、一袋砂糖、一罐 Nutella、一罐 golden syrup。Tom 坐在台子上吃着第一张："This one\'s mine, you make your own."',
    choices: [
      { label: '让 Sarah 教你抛 pancake', effect: { energy: 3, belonging: 8, wallet: -3, npc: { sarah: 2 } },
        feedback: 'Sarah 教你手腕的角度——"Flick, don\'t throw." 你第一张 pancake 飞起来撞到了 cooker hood，半边焦了。Tom 笑到从台子上滑下来。\n\n第三张你成功翻了一次。Sarah 拍照发了 IG："New flatmate skills unlocked." 你被 tag 了。\n\n这是你来英国第一次出现在别人的 IG story 里。' },
      { label: '装传统 Crêpe 派 + 柠檬 + 糖', effect: { energy: 5, belonging: 6, wallet: -3 },
        feedback: '你认真挤了柠檬汁 + 撒砂糖。Sarah 看着你点头："That\'s the right way. Tom\'s a Nutella heathen."\n\nTom 大叫："Excuse me??" 你们三个在厨房吵了 10 分钟"正确的 pancake topping"——你才发现 Brits 对这个比对脱欧还认真。' },
      { label: '一群朋友约下午茶 pancake stack', effect: { energy: 5, belonging: 12, wallet: -22 },
        condition: ({ npcRel }) => anyRel(npcRel, 4),
        feedback: '你和 3 个朋友约在 Soho 一家叫 Where The Pancakes Are 的店——队伍 25 分钟。\n\n你点了"Lemon & sugar stack"（最传统）。一个朋友点了 Nutella + banana，被 Sarah（如果在场）当场吐槽 30 秒。\n\n回去地铁上每个人手机里都存了 6 张 pancake 照片。其中 1 张你们 4 个人合影发到了 group chat——这是这学期第一次有人想到要把你拍进合照。' },
      { label: '"我图书馆赶 essay"', effect: { energy: -2, academic: 3, belonging: -3 },
        feedback: '你戴耳机出门。背后 Tom 在唱"Pancake pancake pancake"。\n\n你 7 点回来，厨房收拾干净了，桌上留了一张折好的 pancake + 一张便条："Saved you one. — Sarah"' },
    ],
  },

  // ─────────────────────────────────────────────────────────────
  // W23 Mother's Day UK · 极个人。保留原样。
  // ─────────────────────────────────────────────────────────────
  mothers_day: {
    title: '英国的母亲节', emoji: '💐',
    body: '你刷 Instagram。所有英国朋友都在发"Happy Mother\'s Day"。你妈不知道这天——中国母亲节是 5 月。',
    choices: [
      { label: '提前给妈妈打电话', effect: { energy: -3, belonging: 12 },
        feedback: '你说："妈，今天是英国的母亲节。" 她笑了："那我今年提前过了。" 然后她沉默几秒，"早点睡 别熬夜。"' },
      { label: '跟妈视频 + 你做了道菜云端给她看', effect: { energy: 3, belonging: 16, wallet: -15 },
        feedback: '你早上跟着小红书学着做了一锅她那道粉蒸肉——她每年生日都做这一道。\n\n你拍了一张端上桌的照片发她："妈 你看 我做的。"\n\n她过了 10 分钟才回——视频拨过来——她在厨房，背景里是同一道菜。她说："你那个肉切得太厚了。下次薄一点。" 然后语气一软："但你做了。我们一起吃。"\n\n两个人隔着 8 小时时差吃同一道菜。你哭了。她说"傻孩子"。' },
      { label: '什么都不做', effect: { energy: 0, belonging: -3 },
        feedback: '你刷完朋友圈关了手机。你想，等到 5 月那天再说。但你也知道，如果你今天没想到她，5 月那天她也未必能感到。' },
    ],
  },

  // ─────────────────────────────────────────────────────────────
  // W27 清明 · 个体哀悼。+ 朋友陪伴的轻接触选项。
  // ─────────────────────────────────────────────────────────────
  qingming: {
    title: '清明节 · 你扫不了的墓', emoji: '🕯️',
    body: '4 月 5 日。你妈早上发来一张照片——你爷爷的墓前，鲜花、烧纸、糕点摆得整齐。\n\n配文："今年我们替你去了。"\n\n爷爷走的时候你 19 岁。墓在北京西郊。你来伦敦后第一个清明。\n\n复活节假期的 ensuite 安静得能听到走廊里的脚步声。',
    choices: [
      { label: '在 Hyde Park 找个角落静坐 30 分钟', effect: { energy: 3, belonging: 8, flag: 'qingming_park' },
        feedback: '你走到 Serpentine 边上。3 月底的伦敦还没真的暖起来。你坐在长椅上想爷爷——他给你买的第一辆自行车、他在阳台上养的兰花、他最后一次给你的红包压在你皮夹里到现在。\n\n一只松鼠跳到你脚边。你笑了一下。然后哭了 5 分钟。\n\n你给妈发："今天我也想他了。" 她半小时后回："爷爷知道。"' },
      { label: '想烧张纸 · 在阳台 / 后院 metal tin 里小心翼翼', effect: { energy: -3, belonging: 4 },
        feedback: '你用 A4 纸写了"爷爷"两个字。\n\n想烧——但 hall 走廊烟雾报警器到处都是，warden 通告白纸黑字写过"any open flame indoors = immediate fine £150 + escalation"。\n\n你最后在后院找了个 metal biscuit tin。Tom 在窗边看到你 — 他没说什么，只是端了一杯茶过来站旁边。\n\n纸烧得很慢。你看着灰飘起来——风把它带向 Edgware Road 方向。你想：这一缕烟离北京 8000 公里，但烧得跟家里一样慢。\n\n回 ensuite 你给妈发："今天烧了一张。" 她回："傻孩子。"' },
      { label: '给妈视频 1 小时', effect: { energy: -3, belonging: 15 },
        feedback: '妈给你看墓前的花。爸在背景里抽烟没说话。你说"明年清明我回去看爷爷"——妈没回这句，她说"不要赶着回 你学业重要"。\n\n你挂电话后坐了 20 分钟没动。\n\n你想：原来"出国留学"的代价里有一项叫"扫不了的墓"。' },
      { label: '约一个朋友一起 Hyde Park 散步 + 讲爷爷', effect: { energy: 0, belonging: 18, npc: {} },
        condition: ({ npcRel }) => anyRel(npcRel, 5),
        feedback: '你叫了关系最好的那个朋友。Hyde Park 走了 2 圈。\n\n你 30 分钟没说话——他/她也没问。然后你突然开口："我爷爷 3 年前走了。今天是我们清明节。我没回去过。"\n\nta 听完了没安慰。沉默 2 分钟。然后说："Tell me about him." 你说了 1 小时。\n\n回去路上 ta 给你买了一杯 Pret latte——什么都没多说，但杯子很烫。这种 belonging 比任何节日都重。' },
      { label: '今天不想想这些', effect: { energy: 0, belonging: -5 },
        feedback: '你打开 Netflix 看了一整天 Black Mirror。每当 Whatsapp 弹出妈的消息你都没点开。\n\n晚上你看到她发了一句"睡了 别熬夜"。你回了一个晚安。\n\n你不是不想他——你只是不知道在伦敦这个 ensuite 里怎么想。' },
    ],
  },

  // ─────────────────────────────────────────────────────────────
  // W38 Trooping · dissertation 期。Sarah 家庭路线 = 高 rel。
  // ─────────────────────────────────────────────────────────────
  kings_birthday: {
    title: 'Trooping the Colour', emoji: '🎖️',
    body: '6 月某个周六。你从 ensuite 出门去图书馆——刚走到 Russell Square 就发现整个伦敦地铁绿色线全部 partial closure。\n\nGoogle 一查：今天是 King\'s Official Birthday。Trooping the Colour 在 Horse Guards Parade。BBC One 直播皇室全家阳台挥手。Mall 上现在堵满游客。\n\n你 dissertation 写得正辛苦。但你也想——这种事一年只一次。',
    choices: [
      { label: '跟 Sarah 家人一起 family insider 路线', effect: { energy: -5, belonging: 18, wallet: -8, npc: { sarah: 3 } },
        condition: ({ npcRel }) => (npcRel.sarah || 0) >= 5,
        feedback: 'Sarah 说："My dad goes every year — he was Royal Engineers. Want to join us? Best view\'s actually from Horse Guards directly, not the Mall."\n\n你跟着她爸（穿西装戴勋章）走到了一个游客绝对挤不进的角落。骑兵队从你 3 米外走过——Sarah 爸小声跟你说"那个是 Blues and Royals, 那个是 Life Guards"。\n\n你回家路上想：如果没有 Sarah，今天你大概在图书馆。一个英国朋友能给你打开一座城市的另一面。' },
      { label: '挤过去 Mall 上看一眼', effect: { energy: -8, belonging: 6, wallet: -3, flag: 'trooping_seen' },
        feedback: '你挤了 25 分钟才挤到 St James\'s Park 边缘。完全看不到 Buckingham Palace——全是头。但有那么一瞬间，红色制服的骑兵队从你右边 5 米外穿过，马蹄声整齐得像节拍器。\n\n你旁边一个美国老太太对你说："Worth it, isn\'t it?" 你点头。\n\n你回去时已经 4 点。dissertation 那一段写不下去了。但你想——明年此时我大概率不在伦敦了。今天值的。' },
      { label: '"算了 直接图书馆" 绕道', effect: { energy: -3, academic: 5 },
        feedback: '你绕了 20 分钟从 Holborn 进 SOAS 图书馆。整个 4 楼空空荡荡。\n\n你写完了 dissertation 第三章 1500 字。\n\n但你晚上回去刷 IG，看到 Sarah 在 Mall 上和家人合照——她说她爸是退伍军人 always go。你点了赞，没评论。\n\n有些文化时刻，你只能旁观。' },
    ],
  },

  // ─────────────────────────────────────────────────────────────
  // W40 Pride · dissertation 期。Aditi/Sarah march 路线 = 高 rel。
  // ─────────────────────────────────────────────────────────────
  pride: {
    title: 'Pride London · Soho 全城彩虹', emoji: '🏳️‍🌈',
    body: '6 月最后一个周六。Soho 整条 Old Compton Street 封路。\n\n早上你刷 IG 看到——Aditi 转发了一条"March with us"，Sarah 在 story 里穿着彩虹背心，凯泽（CSSA）在群里发"今天去 Soho 看 parade 的兄弟姐妹注意安全"。\n\n你站在 ensuite 想 dissertation 写到哪了。然后想——你来伦敦一年，还没真正去过 Soho 一次。',
    choices: [
      { label: '跟 Aditi/Sarah 一起 march', effect: { energy: -8, belonging: 18, wallet: -8, flag: 'pride_with_friend' },
        condition: ({ npcRel }) => (npcRel.aditi || 0) >= 5 || (npcRel.sarah || 0) >= 5,
        feedback: 'Aditi（如果 rel 高）在 Russell Square 等你。她递给你一支彩色记号笔："Cheek paint. Hold still."\n\n你们走在某个 university LGBTQ+ society 的方阵里——你不是 member 但 Aditi 说"allies welcome"。沿途几万人在欢呼。\n\n中途她挽着你的胳膊小声说："My cousin came out 2 years ago. My family didn\'t take it well. I wish she could see this." 你说："Maybe she will, one day." 你们没再说话，继续走。\n\n这是你来英国 belonging 最重的一天——不是因为你属于哪个群体，是因为你站在了一个朋友的身边。' },
      { label: '一个人去 Soho 看 parade', effect: { energy: -5, wallet: -5, belonging: 8, flag: 'pride_solo' },
        feedback: '你挤进 Old Compton Street。彩虹旗、汗、酒精、欢呼。一个穿亮粉色裙子的男生递给你一面小旗："Hey new friend! Welcome!"\n\n你没说话只是接过来。\n\n下一辆 float 是某家律所的 Pride 队伍——10 个西装在车上跳舞。你笑了出来——伦敦这个城市就是这样：周一她严肃得像本字典，周六她可以是这个样子。\n\n你举着那面小旗走了 4 个小时。' },
      { label: '"我 dissertation 赶不完"', effect: { energy: -3, academic: 4 },
        feedback: '你戴耳机进 SOAS 图书馆。今天人少得反常——大家都去 Soho 了。\n\n你写完了 1200 字。\n\n晚上你刷 IG 看 Aditi 发的 9 张合照——她笑得灿烂得不像她。\n\n你点赞，评论"looks amazing"。她回了三颗心。' },
      { label: '"那不是我应该参与的"', effect: { energy: 0, belonging: -5 },
        feedback: '你回 ensuite 写了一下午 dissertation。手机静音。\n\n晚上你看朋友圈——某个国内同学发了一条"国外那种活动我们不要凑热闹"。你点开评论区，3 个人在附和。\n\n你关掉手机。你不知道你今天的决定有几分是自己的，几分是从那条评论区里学来的。' },
    ],
  },

  // ─────────────────────────────────────────────────────────────
  // W44 Notting Hill · 临毕业。一群朋友一起 = 高 rel。
  // ─────────────────────────────────────────────────────────────
  notting_hill: {
    title: 'Notting Hill 嘉年华', emoji: '🎉',
    body: '8 月最后一个周末。Westbourne Park 站封站。Notting Hill 整片区被加勒比鼓声、烤鸡香味、20 万人占领。\n\n你 dissertation 已经在 final edit。Sarah 发消息："Carnival! You\'ve gotta come at least once. Bring water and lose your dignity."',
    choices: [
      { label: '一群朋友约一起去 跳一整天', effect: { energy: -12, wallet: -25, belonging: 22, flag: 'carnival_squad' },
        condition: ({ npcRel }) => anyRel(npcRel, 5),
        feedback: '你们 4 个人 11 点在 Ladbroke Grove 集合。买了 £8 的"jerk chicken + rice"和一罐 Red Stripe。一辆花车开过——音箱大得能震碎你的胸腔——你们整队人冲进了人群跳舞。\n\n下午 4 点你们走丢了一次（Sarah 在 sound system 旁边狂跳），又重新汇合。傍晚一个朋友哭着说"this is the best year of my life"——大家都没问她为什么哭，只是凑过去抱了一下。\n\n你回家时鞋上全是泥，T 恤湿透，耳朵嗡嗡响 3 小时没消。但你笑着洗澡。\n\n伦敦给你的告别礼物，就是这一天。' },
      { label: '一个人挤进去看花车 + 跳一跳', effect: { energy: -10, wallet: -15, belonging: 14, flag: 'carnival_in' },
        feedback: '你在 Ladbroke Grove 被人潮推着走。一辆花车开过——音箱大得能震碎你的胸腔。一个加勒比奶奶塞给你一片烤鸡："Eat, baby!" 你嚼着烤鸡跟着鼓点跳了一段——你不知道是什么舞，但旁边没有人在意。\n\n你回家时鞋上全是泥，T 恤湿透，耳朵嗡嗡响 3 小时没消。但你笑着洗澡。\n\n这是你伦敦一年里最不像留学生的一天。' },
      { label: '远远看一眼就回家', effect: { energy: -3, belonging: 4 },
        feedback: '你站在 Notting Hill Gate 站外远远看了 10 分钟。鼓声从街那头传来，能感觉到地在震。\n\n你回去了。\n\n但你回去路上发了一条朋友圈——一张远景。15 个人点赞。' },
      { label: '"人太多 我图书馆"', effect: { energy: 0, academic: 3, belonging: -3 },
        feedback: '你 dissertation final edit 顺利。\n\n但 Sarah 第二天发了你们仨一张合照——她、Aditi、还有一个你不认识的人。配文 "Carnival 2025!"。\n\n你滑过去，没有评论。' },
    ],
  },
};
