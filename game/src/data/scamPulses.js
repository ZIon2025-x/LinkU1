// 反诈线"诱饵期" pulses。
//
// 6 条反诈线（storylines.js）每条 3-4 章 milestone，章与章之间是 5-8 周
// 真空期。但真实诈骗最危险的恰恰是这段——攻击者用日常 ping 慢慢织你。
//
// 这些 pulse 事件:
//   1. 不推进剧情 (不 set 新 flag) — 只是让玩家看到攻击者在背景持续 active
//   2. 大多 1 选项 — 这是 atmospheric event 不是 hard choice
//   3. 用 storyline-set 的 flag 做 gating: 如 romance_daniel_started AND NOT
//      romance_daniel_invested → ch1-ch2 之间窗口
//
// 玩家事后回看会意识到：那些温暖的 voice note、点赞、podcast 推荐——
// 都是脚本。

export const SCAM_PULSE_EVENTS = {
  flat: [
    // ─── Daniel (女玩家 杀猪盘) · ch1→ch2→ch3 之间 ───
    {
      id: 'pulse_daniel_voice_note', minWeek: 14, maxWeek: 17, repeatable: true,
      title: 'Daniel · 5 分钟 voice note',
      condition: ({ flags }) =>
        !!flags.romance_daniel_started && !flags.romance_daniel_invested && !flags.scam_pig_resisted,
      body: '凌晨 11 点。你 ensuite。Hinge notification — Daniel 发了一条 5 分 12 秒的 voice note。\n\n你点开——他声音很低，背景有海风。"想跟你聊一下我小时候在新加坡西部那边——我爸刚搬过去那两年..."\n\n他讲了一个 5 分钟的童年故事——关于他妈妈第一次在 hawker center 找不到回家路。',
      choices: [
        { label: '听完 + 回一条长 voice note', effect: { energy: -3, belonging: 4 },
          feedback: '你回了一条 8 分钟的——讲你爷爷。\n\n他 30 秒后回："That was beautiful. Goodnight love."\n\n你睡前想——为什么 Hinge 上能遇到这么对得上话的人。' },
        { label: '"听了 但今晚累 短回"', effect: { energy: 1 },
          feedback: '你回了一句"That was lovely. Sleep well."\n\n他："You too babe ❤️"。' },
      ],
    },
    {
      id: 'pulse_daniel_ig_story', minWeek: 16, maxWeek: 19, repeatable: true,
      title: 'Daniel · IG story 是 Mayfair 私人会所',
      condition: ({ flags }) =>
        !!flags.romance_daniel_started && !flags.romance_daniel_invested && !flags.scam_pig_resisted,
      body: '你刷 IG。Daniel 发了一个 story：Mayfair 某个 private members club 的木门 + 一杯 negroni。geotag "Annabel\'s, London"。\n\n他很少发 IG—这是这一周第二条。',
      choices: [
        { label: '点 reaction + DM "看着不错"', effect: { energy: 1, belonging: 2 },
          feedback: '他 30 秒后 DM："Client dinner. Boring tbh. I\'d rather be on FaceTime with you ❤️"\n\n你笑了一下放下手机。\n\n（你不会知道——那张照片是他从 Pinterest 找的。Annabel\'s 真实会员费 £4,000/年——他不是。）' },
      ],
    },
    {
      id: 'pulse_daniel_headspace_gift', minWeek: 18, maxWeek: 20,
      title: 'Daniel · "I bought you Headspace"',
      condition: ({ flags }) =>
        !!flags.romance_daniel_invested && !flags.scammed_pig_full && !flags.scammed_pig_partial && !flags.scam_pig_resisted,
      body: '邮箱通知——Headspace 发来一封 "[Daniel] gave you a gift!" 12 个月订阅 (£59.99)。\n\nDaniel 紧接着 voice note："Babe you mentioned dissertation stress last week. I got you 12 months of Headspace. Use it. I want you sleeping well."',
      choices: [
        { label: '感动 + 长 voice note 谢他', effect: { energy: 3, belonging: 6 },
          feedback: '你回 6 分钟 voice note——讲你妈，讲压力，讲遇到他之后伦敦没那么孤独。\n\n他："That\'s what I\'m here for."\n\n你睡前想——他真的 see 我。\n\n（你 1 个月后会发现——Headspace gift 是他唯一付过的钱。£59.99 是他 5 周脚本的 sunk cost。这是他的诱饵成本。）' },
      ],
    },

    // ─── Diana (男玩家 杀猪盘) · 镜像 ───
    {
      id: 'pulse_diana_voice_note', minWeek: 14, maxWeek: 17, repeatable: true,
      title: 'Diana · 4 分钟 voice note',
      condition: ({ flags }) =>
        !!flags.romance_diana_started && !flags.romance_diana_invested && !flags.scam_pig_resisted,
      body: '凌晨 11 点。Hinge notification — Diana 发了 4 分 23 秒 voice note。\n\n声音是港式英语——她讲她妹妹今年高考、她爸最近从香港搬到墨尔本、她周末看了一部新电影 want to discuss with you。',
      choices: [
        { label: '听完 + 长 reply', effect: { energy: -3, belonging: 4 },
          feedback: '你回 5 分钟 voice note——讲你妹妹（如果你有）、讲你爸的重男轻女、讲你北京老家。\n\n她："谢谢你信任我说这些。" 后面一颗 ❤️。\n\n你睡前想：这种女生我配吗。' },
      ],
    },
    {
      id: 'pulse_diana_ig_story_annabel', minWeek: 16, maxWeek: 19, repeatable: true,
      title: 'Diana · IG story 是 Mayfair Annabel\'s',
      condition: ({ flags }) =>
        !!flags.romance_diana_started && !flags.romance_diana_invested && !flags.scam_pig_resisted,
      body: 'Diana 发 IG story——Mayfair Annabel\'s 木门 + 一杯红酒。geotag "Annabel\'s, London"。',
      choices: [
        { label: '点 reaction + "羡慕"', effect: { energy: 1, belonging: 2 },
          feedback: 'Diana DM："Partner 应酬 真的好烦 我宁愿在 FaceTime ❤️"\n\n你回了一句 "next time take me"。她："等我有空 一定。"\n\n（这条 story 也是 Pinterest。她到现在没真的离开过她合租的 ensuite。）' },
      ],
    },
    {
      id: 'pulse_diana_audible_gift', minWeek: 18, maxWeek: 20,
      title: 'Diana · "I gifted you Audible"',
      condition: ({ flags }) =>
        !!flags.romance_diana_invested && !flags.scammed_pig_full && !flags.scammed_pig_partial && !flags.scam_pig_resisted,
      body: '邮件通知——Audible "Diana 送了你 12 个月订阅 (£79.99)"。\n\nDiana voice note："Babe 你说 essay 期间没时间读书 我送你 audible 你 walking 时听。"',
      choices: [
        { label: '感动 + 谢她', effect: { energy: 3, belonging: 6 },
          feedback: '你回："谢谢宝。" + 一颗心。\n\n她："That\'s what I\'m here for."\n\n（Audible £79.99 是 Diana 5 周里花的全部钱。那是她的 fishing equipment。）' },
      ],
    },

    // ─── Lyn 姐 (美妆 MLM) · ch1→ch2 之间 ───
    {
      id: 'pulse_lyn_morning_post', minWeek: 9, maxWeek: 13, repeatable: true,
      title: 'Lyn 姐 · 早安朋友圈',
      condition: ({ flags }) =>
        !!flags.lyn_started && !flags.lyn_pitch_in && !flags.scam_cosmetic_resisted,
      body: '早 7:30。你刚醒。\n\nLyn 姐朋友圈又发了——她拿一杯 latte + 阳台俯瞰 Notting Hill 的角度。配文："姐妹们 今天也要爱自己 ✨ 我用了 3 年的护肤套装见效快 私聊我有惊喜 💕"\n\n下面 8 个赞。你看了 3 秒滑过去。',
      choices: [
        { label: '点赞 + 滑过去', effect: { energy: 0, belonging: 1 },
          feedback: '你点了赞。她 30 秒后给你私聊："小妹妹早 ✨ 今天我有一支 Charlotte Tilbury 的小样多 你要不要 我 9:30 出门 path 上经过你 ensuite 我给你 drop 一支 不要钱 ❤️"\n\n你回"那不好意思 谢学姐"。\n\n这是她 funnel 第 7 天。' },
      ],
    },
    {
      id: 'pulse_lyn_free_sample', minWeek: 10, maxWeek: 14,
      title: 'Lyn 姐 · 真的来送了一支唇膏',
      condition: ({ flags }) =>
        !!flags.lyn_started && !flags.lyn_pitch_in && !flags.scam_cosmetic_resisted,
      body: '11:45 AM。你 ensuite 楼下接到 Lyn 姐——她真的来了。\n\n递给你一支 Charlotte Tilbury Pillow Talk 唇膏（£30 Selfridges 价）。"妹妹你皮肤底子好 这色显气色。" 她抱了你一下——香水味很贵。\n\n她笑着："不收钱不收钱 妹妹 you deserve nice things。"',
      choices: [
        { label: '感谢收下', effect: { energy: 2, belonging: 3, wallet: 0 },
          feedback: '你回 ensuite 涂了一下——确实显气色。你给妈视频："妈这个口红一个学姐送我的 £30 的。"\n\n你妈："这世界上谁这么好。"\n\n你笑："学姐就是这样。"\n\n（你不知道——她下周会让你来 Notting Hill 公寓 onboarding tea。这一支 £30 的口红是她 customer acquisition cost。）' },
      ],
    },

    // ─── Eric 哥 (Forex) · ch1→ch2 之间 ───
    {
      id: 'pulse_eric_morning_plan', minWeek: 9, maxWeek: 13, repeatable: true,
      title: 'Eric 哥 · 早 6:30 Discord trade plan',
      condition: ({ flags }) =>
        !!flags.eric_mentor_started && !flags.eric_doubted && !flags.scammed_trading_partial && !flags.scammed_trading_full,
      body: '早 6:30。Discord notification 把你叫醒。\n\nEric 哥发了今日 trade plan 截图："GBP/USD short @ 1.2745 SL 1.2780 TP 1.2680 RR 1:1.8。资金管理 0.5% per trade。"\n\n下面 5 个 brothers 在排队"Got it 哥"。',
      choices: [
        { label: '截图存手机', effect: { energy: -1, academic: 1 },
          feedback: '你存了截图。中午回看——他真的 hit TP 了 +63 pips。\n\n你看着自己的 ensuite 想："这哥们一上午挣的比我 Mei 姐工资 1 周还多。"\n\n（你不会知道——他截图里的 P&L 是 Photoshop。他后台账号可能从来没真的 trade 过。但那张图调动你的 dopamine 调动了 5 周。）' },
      ],
    },
    {
      id: 'pulse_eric_voice_call', minWeek: 11, maxWeek: 14,
      title: 'Eric 哥 · "兄弟 voice 一下"',
      condition: ({ flags }) =>
        !!flags.eric_mentor_started && !flags.eric_doubted && !flags.scammed_trading_partial && !flags.scammed_trading_full,
      body: '周三晚 9 点。Discord voice call — Eric 哥单独叫你。\n\n他声音很 chill："哥们 今天市场看你紧张了 跟你 chat 5 分钟。我 25 岁那年我爸生意亏了 我也是从一个 ensuite 开始练交易的。"\n\n他讲了一个 10 分钟的"我也是过来人"故事。',
      choices: [
        { label: '认真听 + 感谢', effect: { energy: -2, belonging: 4 },
          feedback: '你说"谢哥 你是我在伦敦少有的真听我说话的人。"\n\nEric："咱们 brothers in arms 老弟。"\n\n你挂掉 voice call 想——这种 mentor 一辈子能遇到几个。\n\n（"我也从 ensuite 开始"那段——他在 2 个不同 cohort 里讲过。你是这一批听这个剧本的第 7 个。）' },
      ],
    },

    // ─── Emma 学姐 (Networking MLM) · ch1→ch2 之间 ───
    {
      id: 'pulse_emma_podcast_recommendation', minWeek: 7, maxWeek: 11, repeatable: true,
      title: 'Emma 学姐 · 推荐 Tim Ferriss podcast',
      condition: ({ flags }) =>
        !!flags.emma_mlm_started && !flags.emma_pitch_in && !flags.emma_doubted && !flags.scam_mlm_resisted,
      body: '微信 — Emma 学姐："学妹 / 学弟 我在 tube 上听 Tim Ferriss 这一期讲 \'how to think about your 20s\' 笔记我整理出来给你看了 18 张图 给你启发。"\n\n附 18 张她手写笔记——字真的很整齐。',
      choices: [
        { label: '认真看 + 谢她', effect: { energy: 1, academic: 2, belonging: 3 },
          feedback: '你看了 30 分钟。第 12 张那条 "your network is your ceiling" 你截图存了。\n\n你回："学姐这个 mind-blowing 谢谢。"\n\nEmma："不客气 ❤️ 下周聚会我们一起 unpack 这条。"\n\n（Tim Ferriss 那本书她其实没读过——她 ChatGPT 5 分钟生成的笔记照抄。但你不会知道。）' },
      ],
    },
    {
      id: 'pulse_emma_essay_review', minWeek: 9, maxWeek: 12,
      title: 'Emma 学姐 · 帮你看 essay outline',
      condition: ({ flags }) =>
        !!flags.emma_mlm_started && !flags.emma_pitch_in && !flags.emma_doubted && !flags.scam_mlm_resisted,
      body: '你 essay outline 卡了 3 天。Emma："学妹 / 学弟 你 essay 把 outline 发给我 我半小时看一下 我以前 LSE 的时候 essay 全 distinction。"\n\n你将信将疑发过去。\n\n45 分钟后她返还——上面 12 个红色批注 + 3 个 reframe 建议。比你 tutor 的 feedback 还细。',
      choices: [
        { label: '惊讶 + 真心感谢', effect: { energy: 2, academic: 5, belonging: 6 },
          feedback: '你按她建议改。一周后那篇 essay 拿了 72。\n\n你给 Emma 发感谢长文。她："我帮你 because I believe in you 学妹 / 学弟 ❤️ 周二聚会一定来。"\n\n你回"一定"。\n\n（她那 12 个红批注真的细——因为她真的有 LSE 的 academic 训练。她的 funnel 之所以 effective 就是因为她真的能给 value。这就是高级 MLM 的 sophistication：你拿到的是真东西，但代价是后面的 starter kit。）' },
      ],
    },
    {
      id: 'pulse_emma_mayfair_invite', minWeek: 11, maxWeek: 13,
      title: 'Emma 学姐 · "Women in Business 周二聚会"',
      condition: ({ flags }) =>
        !!flags.emma_mlm_started && !flags.emma_pitch_in && !flags.emma_doubted && !flags.scam_mlm_resisted,
      body: 'Emma 微信："学妹 / 学弟 周二晚 7 点 我们 Women in Business London 月度聚会 我朋友 host 在 Mayfair 一栋公寓 30 个 inspiring 的 30+ 亚裔女性 / 男性 你来认识。穿 smart casual。带个 notepad。"\n\n附一张地址——Mayfair Charles Street W1。',
      choices: [
        { label: '"好 我来"', effect: { energy: 1, belonging: 2 },
          feedback: '你回了"好"。\n\n第二天她发"穿那件米色大衣 weather permit 行 ❤️"——你愣了 2 秒。她什么时候见过你穿米色大衣？\n\n你想了想——可能朋友圈见过。\n\n（她每周筛新生 — 她朋友圈翻看每个新加的人 100 条。你穿过什么大衣 / 喜欢吃什么 / 跟谁吃过饭 — 她都 mental notes 过。这是她"温度"的来源。）' },
      ],
    },

    // ─── 通用反诈 awareness pulses (与具体 scam 解耦) ───
    {
      id: 'pulse_cssa_warning_amazon', minWeek: 6, maxWeek: 50, repeatable: true,
      title: 'CSSA 群 · "Amazon 假邮件警告"',
      condition: ({ flags }) => !!flags.cssa,
      body: 'CSSA 群里凯泽发："家人们注意 — 今早收到一封\'Amazon: 您账户因可疑活动被冻结 请点击验证\' 的邮件 域名是 amaz0n-uk.cn。已经有 3 个学弟问我了。一律不要点。直接 amazon.co.uk 网站登录看你账户。\n\n潜水的人（出现）：HMRC、DVLA、Amazon、Royal Mail 任何附\'立即验证\'\'账户冻结\'链接的邮件 99% 假。"',
      choices: [
        { label: '截图存手机 + 给爸妈发警告', effect: { energy: 1, belonging: 6, academic: 1 },
          feedback: '你截图发给你妈。她："我一会儿告诉你爸 他什么破链接都点。"\n\n这种群体反诈意识是你来英国这 6 个月最隐形的 ROI 之一。' },
      ],
    },
    {
      id: 'pulse_cssa_warning_visa_call', minWeek: 12, maxWeek: 50, repeatable: true,
      title: 'CSSA 群 · "假 UKVI 电话"',
      condition: ({ flags }) => !!flags.cssa,
      body: 'CSSA 群：新生小王："救命 我刚接到一个英国号码说是 UKVI 说我 visa 有问题 让我立刻提供 BRP 号 + 转 £400 \'紧急处理费\' 不然 24 小时内 deport。" \n\n5 秒不到：\n\n上岸了的姐：假的。UKVI 从不打电话。所有 visa 沟通都通过 GOV.UK 信箱或 Royal Mail 信。BRP 号也不会让你电话告知。直接挂断 + block。\n狗哥：我 5 周前接过一模一样电话。当场骂回去。哥们别慌。\n潜水的人：（出现）UKVI 真要找你只会 in writing。任何"立刻"\"deport"\"emergency fee" — 100% scam。',
      choices: [
        { label: 'mark + 转发到家人群', effect: { energy: 1, belonging: 6 },
          feedback: '你 forward 到你和你父母的家人群。你妈秒回："不会有这种事吧？" 你："就是没有 才告诉你。"\n\n3 周后你姨妈在国内接到一模一样电话——她照着你转的那条直接挂了。\n\n你保护的不只是你自己——是你下了 8000 公里。' },
      ],
    },
    {
      id: 'pulse_cssa_warning_recruiter', minWeek: 18, maxWeek: 50, repeatable: true,
      title: 'CSSA 群 · "LinkedIn 假 recruiter"',
      condition: ({ flags }) => !!flags.cssa,
      body: 'CSSA 群：@Lily："姐妹们 LinkedIn 上一个\'Goldman Sachs Asset Management Senior Recruiter Olivia Chen\' 加我说 fast-track interview 然后让我付 £350 background check fee。我已经 google 这是 typical scam。但她头像是真 Goldman 员工 LinkedIn 盗的。\n\n上岸了的姐：mark。Big 4 / GS / MS / BCG 真的 recruiter 永远从公司域名邮箱联系 不会 LinkedIn DM。Candidate 永远不付费。"',
      choices: [
        { label: 'mark + 转给国内同学', effect: { energy: 1, belonging: 6, academic: 1 },
          feedback: '你 forward 给国内还在读本科的表妹。她："姐 我表妹也被加过 BCG 假 recruiter 上周。我以为只有我。"\n\n你笑——这种 scam 是 global 的。你提醒她也提醒了她姐妹圈 5 个人。' },
      ],
    },
  ],
};
