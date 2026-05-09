// Mei's restaurant working sub-arc — 5 events that progress your part-time
// job at Lucky Star from "first shift" to "she leaves you in charge".
//
// Gated entry: existing storyline `mei_2` chapter sets `mei_job` flag when
// player accepts Mei's offer ("好啊 Mei 姐！" choice). These events build on
// that into a real working relationship arc.
//
// Flag chain:
//   mei_job (from existing storyline)
//   mei_first_shift     (W6+, sets mei_serving)
//   mei_difficult_customer (W12+, requires mei_serving)
//   mei_late_night_chat (W18+, sets mei_intimate)
//   mei_promotion       (W24+, requires mei_intimate, sets mei_manager_path)
//   mei_first_paycheck_home (W12+, requires mei_serving) — emotional callback

export const MEI_WORK_EVENTS = {
  mei: [
    {
      id: 'mei_first_shift', minWeek: 6, maxWeek: 30,
      title: '第一次端盘子',
      condition: ({ flags }) => !!flags.mei_job && !flags.mei_serving,
      body: '周五晚 6 点。Mei\'s 客人开始进。\n\nMei 姐递给你一件红围裙："系上。点单要快，端盘子要稳，遇到醉鬼别理。"\n\n你的 first table 是 4 个英国上班族——他们点了麻婆豆腐、宫保鸡丁、北京烤鸭、青菜、3 瓶 Tsingtao。\n\n你重复一遍 order——发现你把"麻婆豆腐"的英文（mapo tofu）说错了。',
      choices: [
        { label: '认真试 + 笑笑改正', effect: { energy: -8, wallet: 50, belonging: 6, flag: 'mei_serving' },
          feedback: '4 个英国人没发觉。Mei 姐从厨房探头瞄一眼："还行。" 那一晚你端了 18 个菜，洒了 2 盘豆瓣酱，但每张账单都收到了。\n\n9 点 Mei 姐塞给你 £45 现金 + 一份免单的炒饭："先这么多。下次稳一点。"\n\n你坐在公交回家边吃炒饭边想：这是你第一次靠自己赚到英镑。' },
        { label: '太紧张 提前撤退', effect: { energy: -3, belonging: -2 },
          feedback: '你撑了 1 小时受不了——洗手间躲了 5 分钟然后跟 Mei 说"今晚不行"。\n\nMei 姐没说话。她让你回家。但下周末她没再叫你来。\n\n你失去了打工机会。也错过了 belonging。' },
      ],
    },
    {
      id: 'mei_difficult_customer', minWeek: 12, maxWeek: 35,
      title: '难处理的客人',
      condition: ({ flags }) => !!flags.mei_serving && !flags.mei_difficult_handled,
      body: '周六晚 8 点。一个 50 岁喝多了的英国白人男 customer 把宫保鸡丁推回："This isn\'t real Chinese. I\'ve been to Beijing. This is fake."\n\n他要 refund + 投诉服务员（你）。其他 customer 在看。Mei 姐从厨房听到了——但她没出来。',
      choices: [
        { label: '冷静 + 用英文解释这是"川菜版本"', effect: { energy: -8, belonging: 10, flag: 'mei_difficult_handled', academic: 2 },
          feedback: '你说："Sir, 宫保鸡丁 is a Sichuan dish—not Beijing. The Beijing version uses different spices. Would you like to try our Beijing duck instead, on the house?"\n\n他愣了 5 秒，然后说"oh"。最后他点了北京烤鸭——免费——然后给你 £10 tip。\n\n你回厨房 Mei 姐在洗碗。她没说话——但她端给你一碗红烧肉 + 米饭。这是她的"我看到了 你做得好"。' },
        { label: '叫 Mei 姐出来处理', effect: { energy: -3, belonging: -2 },
          feedback: 'Mei 姐出来跟那个客人骂了 3 分钟。客人最后 refund 走了。\n\n之后 Mei 姐跟你说："以后你自己处理。我老了 撑不动这个。"\n\n你那一刻明白——Mei 姐让你打工不只是 favor，是在 train 你成为下一个像她一样能撑这家店的人。' },
        { label: 'Refund + 道歉', effect: { wallet: -25, energy: -5, belonging: -4 },
          feedback: '你 refund 了。客人走了。后桌一个英国老太太说"I\'ve been eating here 20 years, that man was a tosser"。\n\nMei 姐第二天扣了你 £25 工资——"refund 是从你工资走的 不是从我"。\n\n你想：原来 hospitality 不只是 customer is always right。' },
      ],
    },
    {
      id: 'mei_late_night_chat', minWeek: 18, maxWeek: 36,
      title: 'Mei · 打烊后的故事',
      condition: ({ flags }) => !!flags.mei_serving && !flags.mei_intimate,
      body: '周六晚 11 点打烊。你在拖地。Mei 姐坐在角落小桌——前面一杯热茶。\n\n她说："过来坐。今晚客人少。"\n\n你坐下。她给你倒了一杯茶：\n\n"我 1995 年来的伦敦。22 岁。比你现在还小。我老公那时候在 Soho 一家中餐馆洗碗 £2/小时。我们俩攒了 3 年，开了这家店——15 平米。"',
      effect: { energy: 3, belonging: 18, flag: 'mei_intimate' },
      feedback: '她讲了 40 分钟——你没插嘴一句。\n\n她讲了：\n· 她妹妹被办签证骗去意大利做工 一辈子没出来\n· 她大儿子刚学会走路被她抱着站在收银台后\n· 1997 年回归那年她哭了一个月不知道自己应该高兴还是怕\n· 她为什么对中国留学生好——"你们都是别人家的孩子。在异乡。我懂。"\n\n12 点你出门。她叫你："明天不用早来。睡到中午。"\n\n你坐公交回去时想：我大学毕业找工作的所有焦虑，跟她 22 岁站在收银台背着孩子比，根本不算什么。',
    },
    {
      id: 'mei_promotion_offer', minWeek: 24, maxWeek: 40,
      title: 'Mei · "你管点单系统吧"',
      condition: ({ flags }) => !!flags.mei_intimate && !flags.mei_manager_path,
      body: 'Mei 姐周一下午把你叫到柜台后："你比我儿子还会用电脑。我们点单系统现在用纸——你能不能把它搞成 iPad？"\n\n你 google 了一下：Square POS / Lightspeed Restaurant £75/月。她想让你 setup + 培训其他员工。',
      choices: [
        { label: '帮她搞 + 还自己改了菜单 design', effect: { energy: -15, academic: 2, belonging: 14, flag: 'mei_manager_path' },
          feedback: '你 setup 了 Square POS。又自己重做了菜单——加了"留学生套餐"£8.5（炒饭 + 汤 + 茶），目标客户：Bloomsbury 一带的国际学生。\n\n第一个月营业额涨了 18%。Mei 姐看着数字看了 5 分钟。然后说："傻孩子。你要不要毕业之后留在英国？"\n\n这不是雇佣 offer——是邀请。' },
        { label: '"我帮你 setup 但只做这一次"', effect: { energy: -8, belonging: 4 },
          feedback: '你 setup 了系统。员工不会用——你被叫回来 3 次教。每次都"最后一次"。\n\nMei 姐之后没再让你管别的。但她也没炒你。这是英国华人小生意——你 in 是 in、out 是 out 之间没有清晰边界。' },
      ],
    },
    {
      id: 'mei_first_paycheck_home', minWeek: 12, maxWeek: 30,
      title: '第一笔钱 · 寄给妈',
      condition: ({ flags }) => !!flags.mei_serving,
      body: '你这个月在 Mei\'s 总共拿了 £350 现金。\n\n你打开微信——给妈妈："妈 我这个月打工赚了 £350 ≈ ¥3,200。我转 ¥2,000 给你。"\n\n你点 transfer。',
      choices: [
        { label: '点确认 转 ¥2000', effect: { wallet: -180, energy: 5, belonging: 22, flag: 'sent_first_money_home' },
          feedback: '你妈秒回："傻孩子！你自己留着！"\n\n你说："这是我第一次给你转钱 你必须收。"\n\n她沉默 30 秒。然后："那你爸爸呢？" 你说"留着 给爸买双新鞋"。\n\n3 天后你妈给你回了一段语音——你听见她在哭着笑："你长大了。"\n\n这是你来英国 这一年最重的 £180——不是数字，是 transition 的意义。' },
        { label: '"算了 我自己留着"', effect: { wallet: 0, energy: -3, belonging: -3 },
          feedback: '你删了 transfer。心里"自己存着稳一点"。\n\n你妈 1 周后视频："你最近吃饭怎么样？" 你说"挺好的"。\n\n你这一年没给她转过一次钱。\n\n回国后你才发现：钱不重要 重要的是那个"我能给你"的瞬间。你错过了。' },
      ],
    },
  ],
};
