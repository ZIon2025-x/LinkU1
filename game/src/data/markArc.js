// Mark redemption arc — 3-event progression chained on flags from
// existing kitchen confrontation event (`mark_confrontation` in dailyLife.js).
//
// Mark is the kitchen-mess culprit, mentioned in fire alarm aftermath
// ("Mark, please buy your own butter"), kitchen messy, paper-thin walls,
// house meeting. This arc lets the player turn that running joke into
// actual character development.
//
// Flag chain:
//   mark_confrontation choice "Mate, can you wash..." → mark_called_out
//   mark_arc_apology     → mark_apologized
//   mark_arc_friendship  → mark_friend (used by other events / endings)
//   mark_arc_farewell    → mark_kept_in_touch (post-game callback)

export const MARK_ARC_EVENTS = {
  flat: [
    {
      id: 'mark_arc_apology', minWeek: 8, maxWeek: 30,
      title: 'Mark 敲你的门',
      condition: ({ flags }) => !!flags.mark_called_out && !flags.mark_apologized,
      body: '晚上 11 点。你在写 essay。\n\n敲门声。你打开——是 Mark，穿着 Arsenal 卫衣，手里拎着两瓶啤酒。\n\n"Mate, sorry to bother you. Can I come in for a sec?"\n\n他坐在你椅子上 1 秒后说："I\'ve been thinking about what you said in the kitchen. I\'m sorry. I\'m 22, this is the first time I\'ve lived without my mum. She just... did everything. I genuinely didn\'t know."',
      choices: [
        { label: '"Mate, no worries—we\'re all figuring it out"', effect: { energy: 3, belonging: 8, flag: 'mark_apologized' },
          feedback: '你拿了一瓶啤酒。你们聊了 1 小时——他爸是 Tottenham 出租车司机，他是家里第一个上大学的。读 economics，但讨厌它。\n\n临走时他说 "Cheers for being patient with me". 你说 "Cheers for the beer".\n\n这是这一年你第一次真正"理解"一个英国 housemate——不是浪漫化也不是讨厌，就是一个 22 岁的人。' },
        { label: '"It\'s fine"（敷衍）', effect: { energy: 1, belonging: -2 },
          feedback: '你接了啤酒但没真聊。Mark 5 分钟就走了。\n\n他还是会忘记洗锅。但他下次会更尴尬地避开你的眼神。这不是和解——是平行存在。' },
      ],
    },
    {
      id: 'mark_arc_friendship', minWeek: 12, maxWeek: 30,
      title: '"教我洗那个不锈钢锅"',
      condition: ({ flags }) => !!flags.mark_apologized && !flags.mark_friend,
      body: '周日下午。Mark 端着一个被烧黑的炒锅站在厨房——"Mate, I tried to make stir-fry. I think I killed the pan."\n\n锅底糊得像月球表面。你看了 5 秒。',
      choices: [
        { label: '教他怎么救这口锅', effect: { energy: -3, belonging: 12, flag: 'mark_friend' },
          feedback: '你拿出小苏打 + 白醋。你们俩蹲在水池边 30 分钟刷。\n\n他问你 "How did you learn this?" 你说 "我妈打我手"。他笑得趴在台子上："Tiger mum, mate."\n\n锅救回来了。Mark 说"This is the most useful thing I\'ve learned at uni." 你笑了——他可能说真的。\n\n之后他每周日晚上都来你房间问"how do you cook X"。你成了他的 informal cooking tutor。这是英国 housemate 关系最朴素的版本——靠一口锅。' },
        { label: '"Just buy a new pan, mate"', effect: { energy: 1, belonging: 2 },
          feedback: 'Mark 笑："Yeah probably. Cheers." 然后他扔了那口锅。\n\n你没成为他的 cooking tutor。但你们现在确实算朋友。' },
      ],
    },
    {
      id: 'mark_arc_farewell', minWeek: 50, maxWeek: 52,
      title: 'Mark 搬走前的卡片',
      condition: ({ flags }) => !!flags.mark_friend,
      body: '5 月。Mark 提前搬走——他爸生病，他要回 Tottenham 帮家里。\n\n他敲你的门："Mate, I\'m off Saturday. Just wanted to say... yeah." 然后他递给你一张卡片——Tesco 卖的那种 £3 generic "thank you" 卡。',
      effect: { energy: 5, belonging: 14, flag: 'mark_kept_in_touch' },
      feedback: '你打开卡。里面 Mark 用很丑的字写：\n\n"Mate. Cheers for being patient with me when I was being a dick. Cheers for the cooking lessons. Cheers for not telling anyone I cried watching Eurovision (you saw, I know).\n\nIf you\'re ever in Tottenham, the boozer next to my mum\'s pub does the best Sunday roast in north London. On me.\n\n— M"\n\n你看着那张 £3 卡看了 2 分钟。\n\n这是英国男生表达真情最 british 的方式——把所有重要的话用 "cheers" 包起来。',
    },
  ],
};
