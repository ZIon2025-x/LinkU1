export const FESTIVALS = {
  6: { id: 'halloween', cn: '万圣节', emoji: '🎃', desc: '英国人在装鬼' },
  18: { id: 'spring_festival', cn: '春节', emoji: '🧧', desc: '微信群在抢红包' },
  19: { id: 'valentines', cn: '情人节', emoji: '💝', desc: '伦敦到处是玫瑰' },
  23: { id: 'mothers_day', cn: '英国母亲节', emoji: '💐', desc: '你妈不知道这天' },
  44: { id: 'notting_hill', cn: 'Notting Hill 嘉年华', emoji: '🎉', desc: '加勒比节日' },
};

export const FESTIVAL_EVENTS = {
  halloween: {
    title: '万圣节夜', emoji: '🎃',
    body: '宿舍楼里所有英国人都装扮起来了。Sarah 是个吸血鬼，Tom 是 Joker。你穿着一件普通的卫衣，站在门口。',
    choices: [
      { label: '随便戴个面具去 party', effect: { energy: -8, belonging: 8, wallet: -15 },
        feedback: '你 £15 在 Tesco 买了个塑料面具，跟着他们去了 student union 的 Halloween party。你跳得不太好，但你没逃跑。这个进步比想象中大。' },
      { label: '说"我不太懂这个节日" 推掉', effect: { energy: 3, belonging: -6 },
        feedback: '你回房间看了一晚上视频。窗外尖叫声、笑声不断。你想，再过 10 年，你会后悔今晚吗？大概会。' },
    ],
  },
  valentines: {
    title: '2 月 14 日', emoji: '💝',
    body: 'Pret 把咖啡杯换成红色的。地铁里的情侣比平时多三倍。你刷着小红书，全是"我男朋友 / 女朋友送的礼物"。',
    choices: [
      { label: '给自己买一束花', effect: { wallet: -15, energy: 5, belonging: 4 },
        feedback: '£15 从 Sainsbury\'s 买的。粉色玫瑰加满天星。你回家把它们插进一个 Tesco Meal Deal 的塑料瓶里。然后看着它们笑了。' },
      { label: '去图书馆假装没事', effect: { energy: -5, academic: 3, belonging: -3 },
        feedback: '图书馆里跟你一样的人比平时多。某种说不出来的、单身留学生的隐秘同盟。' },
      { label: '约 Aditi/王凯/Sarah 一起吃饭', effect: { energy: 3, wallet: -25, belonging: 12 },
        feedback: '你们三个/四个在中餐馆挤一桌。"Forever alone party!" Aditi 举杯。你笑出声。这是你今年最好的 Valentine\'s。' },
    ],
  },
  mothers_day: {
    title: '英国的母亲节', emoji: '💐',
    body: '你刷 Instagram。所有英国朋友都在发"Happy Mother\'s Day"。你妈不知道这天——中国母亲节是 5 月。',
    choices: [
      { label: '提前给妈妈打电话', effect: { energy: -3, belonging: 12 },
        feedback: '你说："妈，今天是英国的母亲节。" 她笑了："那我今年提前过了。" 然后她沉默几秒，"早点睡 别熬夜。"' },
      { label: '什么都不做', effect: { energy: 0, belonging: -3 },
        feedback: '你刷完朋友圈关了手机。你想，等到 5 月那天再说。但你也知道，如果你今天没想到她，5 月那天她也未必能感到。' },
    ],
  },
  spring_festival: {
    title: '大年三十', emoji: '🧧',
    body: '伦敦时间下午 4 点。北京时间凌晨 12 点。微信群里在抢红包，你妈在视频里给你看年夜饭。',
    choices: [
      { label: '点一份外卖庆祝', effect: { wallet: -25, energy: 6, belonging: 4 },
        feedback: '£25 的中餐外卖。味道不太对。但你打开淘宝直播看春晚。这就是你第一次在国外的春节。' },
      { label: '约几个中国同学一起包饺子', effect: { wallet: -40, energy: 10, belonging: 18 },
        feedback: '你们五个人在某个人家里包饺子。皮厚馅少，但这是你们的春节。结束后你走在伦敦街上，第一次觉得这里没那么外国。' },
    ],
  },
};
