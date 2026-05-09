export const LOCATION_EVENTS = {
  tesco: [
    { id: 'yellow_label', title: '黄标抢购', body: '晚上 9 点。Tesco 员工推着小车出来。你和另外三个亚洲面孔同时盯着冷柜。',
      minigame: 'yellow_grab', minWeek: 1 },
    { id: 'tesco_quiet', title: '空旷的超市', body: '下午 3 点的 Tesco。空荡荡。你买了一盒草莓和一袋面包。',
      effect: { wallet: -8, energy: 4 }, minWeek: 1, repeatable: true },
  ],
  pub: [
    { id: 'pub_overheard', title: '吧台听到的话', body: '你听到旁边几个人在说"those Chinese students always..."。你听不全后面的话。',
      choices: [
        { label: '凑近听清楚', effect: { energy: -10, belonging: -8 },
          feedback: '"...always study so hard, makes me feel lazy." 你愣了一下。原来不是你想的那样。但你也没法松口气，因为你已经预设了最坏的情况。' },
        { label: '走开', effect: { energy: -5, belonging: -3 },
          feedback: '你换了个位置。一整晚你都在想他们到底说了什么。' },
      ], minWeek: 4 },
  ],
  park: [
    { id: 'park_dog', title: '一只跑过来的狗', body: '一只 Golden Retriever 突然跑到你脚边，摇尾巴。它的主人在远处喊 "Biscuit! Sorry!"',
      effect: { energy: 8, belonging: 5 },
      feedback: '你蹲下来摸了它。主人跑过来道歉，你说 "He\'s lovely!" 这是你这周说过的最真心的英文。', minWeek: 1, repeatable: true },
    { id: 'park_jog', title: '晨跑的人', body: '你在 Hyde Park 散步。一个跑步的中年男人对你说 "Lovely morning!" 然后跑走了。',
      effect: { energy: 5, belonging: 3 },
      feedback: '你愣了一下。然后笑了。Lovely morning. 是的，今天确实是。', minWeek: 2, repeatable: true },
  ],
  tate: [
    { id: 'tate_painting', title: '一幅画前', body: 'Rothko 的红色色块。你在它前面站了 20 分钟。',
      effect: { energy: 6, belonging: 2 },
      feedback: '一个中年女士走过来站在你旁边。她说 "It makes me cry every time." 你点头。她离开了。你又站了 10 分钟。', minWeek: 3 },
  ],
  library: [
    { id: 'lib_late', title: '凌晨的图书馆', body: '凌晨 2 点。整个 4 楼只有你和一个戴耳机的女生（Aditi）。',
      effect: { academic: 6, energy: -8, belonging: 2 },
      feedback: '你们一直没说话。但你们都知道彼此在这里。这就够了。', minWeek: 4, repeatable: true },
  ],
  station: [
    { id: 'station_choose', title: '选择目的地', body: 'King\'s Cross 站台。屏幕上滚动着各种地名。',
      isTravel: true, minWeek: 6 },
  ],
};
