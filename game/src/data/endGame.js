// W30+ events — second-half-of-year content density.
//
// The game's first 12 weeks (Welcome Week + Autumn Term) have ~60 events.
// W30+ was thinner — most action was just the dissertation grind. This file
// adds the emotional + practical beats of "the year ending" specifically.
//
// Spans housing search (W30-35), dissertation panic (W45-52), goodbye scenes
// (W50-52), and graduation week (W52).

export const END_GAME_EVENTS = {
  flat: [
    {
      id: 'housing_search_2nd_year', minWeek: 30, maxWeek: 36,
      title: '找下学年的房子',
      // 如果玩家已经在 flatHunt arc 里 (flat_shortlist 被设过)，这个 quick-pick 事件就别再触发——
      // 让 flatHunt 那 5-event 的慢节奏走完。否则两条路径同时给 private_flat 会让叙事跳。
      condition: ({ flags }) => !flags.flat_shortlist,
      body: '4 月。CSSA 群里："家人们 大家暑假后还住吗？我学院说 9 月不再保留 ensuite。"\n\n你查了一下你的合同——8 月 31 日到期。9 月之后你需要：\n· 续签 ensuite（如果 PSW 留下且学校还有位）\n· 搬到 private flat（自己找）\n· 回国\n\nCSSA 室友群在凑合租。',
      choices: [
        { label: '续签 ensuite 一年', effect: { wallet: -500, energy: 3, belonging: 4, flag: 'renewed_ensuite' },
          feedback: '你交了 £500 押金锁定下学年位置。同样的房间，同样的 housemate（除了 Mark 已经换走）。\n\n稳是稳。但你也意识到——你在英国住了一年，还没真正"找过自己的家"。' },
        { label: '和同学合租 Zone 2 二居', effect: { wallet: -800, energy: -10, belonging: 12, flag: 'private_flat' },
          feedback: '你们看了 5 套，选了 Hackney 一套 £1,500/月二居。押金 £1,800（每人 £900）。\n\n这是你第一次在英国"成家"——哪怕是合租。冰箱里的牛奶不会再被偷。' },
        { label: '不续签 准备回国', effect: { energy: 5, belonging: -3 },
          feedback: '你给学校发邮件 confirm not renewing。\n\n你订机票的时候手在抖——这一年真的要结束了。' },
      ],
    },
    {
      id: 'dissertation_panic', minWeek: 49, maxWeek: 51,
      title: '论文 deadline 前 5 天',
      body: '你打开 dissertation Word 文档。字数：8,400 / 15,000。\n\n你看了一眼台历——deadline 5 天后。每天必须 1,300 字。Discussion + Conclusion + 30 个 references 还没整理。\n\n你 google "how to write 7000 words in 5 days"——20 个 reddit 帖子全是相同建议："stop googling and write."',
      choices: [
        { label: '搬到 24h 图书馆 5 天不出门', effect: { energy: -25, academic: 12, belonging: -5, flag: 'thesis_grinded' },
          feedback: '你 5 天写了 6,800 字。睡 4 小时一晚。最后 24 小时你穿着 hoodie 看 Whitmore 的 latest feedback——他说 "You\'re close. Tighten the conclusion."\n\n你提交了。15,003 字。3 字超额。\n\n你回家洗了一个 40 分钟的澡。' },
        { label: '熬夜 + ChatGPT 帮草稿', effect: { energy: -15, academic: 5, flag: 'used_ai' },
          feedback: '你用 ChatGPT 写了 conclusion 草稿，自己重写。Turnitin AI Detector 标了 12% AI——刚好在阈值下。\n\n你提交了。但你心里有那一丝"如果他们查了"的不安。\n\n这是 2024 年留学生的新焦虑——你用了，但说不出口。' },
        { label: '联系 supervisor 求 extension', effect: { energy: -3, academic: 0, flag: 'extension_filed' },
          feedback: '你写了 extenuating circumstances form：附了 GP 信（freshers flu 那次）+ housing search 压力。\n\nWhitmore 同意 7 天 extension。你多了 7 天但不需要 panic。\n\nMSc 学位上 deadline 不会写明——但你知道你用了一次"buffer"。' },
      ],
    },
    {
      id: 'last_pret_meal_deal', minWeek: 50, maxWeek: 52,
      title: '最后一次 Pret Meal Deal',
      body: '论文交了。你 walk 进 Pret Tottenham Court Road——你这一年 default 午餐的店。\n\n收银员是 Maria——你认得她，她也认得你（她每次都说 "Have a lovely day, my love"）。\n\n你拿了 chicken & bacon sandwich + Quavers + Innocent。Meal deal £5。',
      effect: { wallet: -5, energy: 3, belonging: 8 },
      feedback: 'Maria 扫码时抬头："Last week before you go home?"\n\n你愣了 2 秒。"How did you know?"\n\n她笑："This time of year, all my regulars look like they\'re saying goodbye to a sandwich."\n\n你笑出声。她递了一个免费的 cookie："On me, sweetheart."\n\n你坐在 Bedford Square 的长椅上吃 cookie。你发现你不想哭，但眼睛在湿。',
    },
    {
      id: 'packing_box_to_china', minWeek: 51, maxWeek: 52,
      title: '寄回国前的整理',
      body: '你买了 4 个 60×40×40cm 的纸箱。预计寄回国的东西：\n· 论文 hard copy 2 本（精装 £35/本 from Ryman）\n· 大衣 + 冬装 4 件\n· Burberry 围巾（如果 Bicester 买的）\n· 给爸妈的礼物\n· 你的 Boots photo booth 那 4 张证件照（傻笑那种）\n· 半瓶老干妈（"国内有但..."）\n\nEMS 国际海运 4 个箱子 = £400。',
      choices: [
        { label: '寄全部 + 自己只带 1 个登机箱回', effect: { wallet: -400, energy: -8, belonging: 5 },
          feedback: '你打包到凌晨 2 点。每件衣服都让你想起一段——这件大衣是 Bonfire Night 那晚穿的、这双鞋走了 40 分钟到 Acton 取 BRP、这件毛衣是妈妈从国内寄来的。\n\n你封箱时眼眶有点红。这些不是衣服，是一年。' },
        { label: '简化 只寄 2 箱 (£200)', effect: { wallet: -200, energy: -3, belonging: 2 },
          feedback: '你扔掉了一半。Tom（如果你认识他）来帮你拎垃圾袋——"Mate, that\'s a lot of stuff for one year."\n\n你说"In China we say \'断舍离\'." 他说 "Bloody hell, that\'s deep."' },
      ],
    },
    {
      id: 'last_call_with_mom', minWeek: 51, maxWeek: 52,
      title: '回国前最后一次视频',
      body: '飞回国前一晚。妈妈打来视频——她在家做晚饭。\n\n"明天几点的飞机？" "下午 4 点起飞。" "几个箱子？" "4 个，3 个寄了，1 个登机。"\n\n她沉默 10 秒。然后说："家里的房间妈给你收拾了。床单换了你小时候那套——蓝色小熊那个。"',
      effect: { energy: 5, belonging: 18 },
      feedback: '你说"妈那个我都 22 岁了..."\n\n她说"妈知道。妈想你小时候的样子。"\n\n你哭了。她说"哎呀别哭别哭 哭完明天眼睛肿"。\n\n挂电话你坐在床上 10 分钟没动。\n\n你想：明天起，家不是这间 ensuite 了。是那张蓝色小熊床单。',
    },
  ],

  mei: [
    {
      id: 'last_visit_mei_returning', minWeek: 51, maxWeek: 52,
      title: '最后一次去 Mei\'s · 回国',
      condition: ({ npcRel, flags }) => (npcRel.mei || 0) >= 4 && !flags.stayed_uk_grad,
      body: '你推门进 Mei\'s。Mei 姐看你一眼："傻孩子哭什么。"\n\n你说"我没哭"。其实你眼眶红的。\n\n她从厨房出来——围裙还系着——给你倒了一杯热茶："说吧 哪天的飞机。"',
      effect: { energy: -5, belonging: 25, flag: 'said_goodbye_mei' },
      feedback: '你说"姐 我后天回国"。\n\nMei 姐没说话。她转身回厨房——5 分钟后端出来一份红烧肉 + 一碗白米饭："吃。免单。"\n\n你边吃边说不出话。她坐你对面也没说话——只是看着你吃。\n\n吃完她从抽屉里拿了一个红包："不多。回国路上买点吃的。"\n\n你打开——里面 £200 现金 + 一张写在收据背面的字条："常回来。这里也是你家。"\n\n你抱了她。她拍你的背："去去去 别哭得跟丢了人似的。"',
    },
    {
      id: 'last_visit_mei_staying', minWeek: 51, maxWeek: 52,
      title: '"姐 我留下来了"',
      condition: ({ npcRel, flags }) => (npcRel.mei || 0) >= 4 && !!flags.stayed_uk_grad,
      body: '你推门进 Mei\'s。Mei 姐看你一眼："今年还来。"\n\n你说"姐 我留下来了 找了工作"。',
      effect: { energy: 3, belonging: 18, flag: 'said_staying_mei' },
      feedback: 'Mei 姐："那好。那以后周末来吃饭。"\n\n她转身回厨房嘀咕："总算这年没白疼。"\n\n你笑了。这一刻你知道——你在伦敦也有家。',
    },
  ],

  uni: [
    {
      id: 'graduation_ceremony', minWeek: 52,
      title: '毕业典礼',
      body: '7 月某天。Royal Festival Hall。\n\n你穿学袍——那块 hood 颜色比你想象中夸张（紫色 + 金色）。同班 80 个人坐在一起——Sarah（如果你认识她）、Aditi、Lin Nan（如果有恋爱线）都在你左右。\n\n你走过台子那一刻——head of department 念你的名字。读音念错了 1 个字，但你笑了。',
      effect: { energy: 5, belonging: 25, flag: 'graduated' },
      feedback: '回到座位你看到爸妈（如果他们来过）—— OR LINK：FLAG `parents_visited`\n\n你脱学袍时风把流苏吹起来。Sarah 拍照："Send it to your mum, mate."\n\n你发给妈。她秒回 9 个 emoji + "我儿子 / 女儿 我心里"。\n\n这一刻你发现——所有的纠结、宿舍的烦恼、Tesco meal deal、4:38 AM 危机、BRP 改名——都在这一张毕业照里。',
    },
  ],
};
