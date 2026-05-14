// 出行随机事件 —— 玩家从一个地点移动到另一个地点时按概率触发。
//
// 玩家选 bus(£2.5)or taxi(£12)。Bus 模式覆盖 tube + bus 公共交通,大部分事件挂这里。
// Taxi 模式基本免疫(坐车里),只有少量"司机攀谈"类事件。
//
// 触发逻辑见 App.jsx _doGoToLocation —— roll 25% chance 抽一条 eligible 事件,
// 优先 first-time (非 repeatable) 的吃完再 random 选 repeatable。

export const TRANSIT_EVENTS = [
  // ─────────────────────────────────────────────────────────────
  // Bus mode · First-time 留学生踩坑
  // ─────────────────────────────────────────────────────────────
  {
    id: 'tube_wrong_direction', mode: 'bus', minWeek: 1, maxWeek: 3,
    title: '第一次坐 Tube · 坐反方向',
    body: 'Piccadilly Line。月台两个方向——Northbound / Southbound。你 Google Maps 截图标的是 "Piccadilly Line"——没说哪个方向。\n\n你随便上一班——3 站后报到一个陌生站名。你才发现自己坐反了。',
    choices: [
      { label: '认输 下车 tap out 反方向重新进',
        effect: { energy: -3, wallet: -3, stress: 3 },
        feedback: '你 tap out 再 tap in，Oyster 重新计费 £3.40。\n\n你到目的地时迟到 25 分钟。' },
      { label: '装老练 + 同站台对面换 Southbound',
        effect: { energy: -2, stress: 2 },
        feedback: '你坐到下一站，同站换 Southbound——Oyster 算同一程，只扣 £2.80。\n\n你迟到 18 分钟。但你学到一条:**Oyster 同站换方向不重新计费**。' },
      { label: '问旁边一个英国大妈',
        effect: { energy: -1, belonging: 4 },
        feedback: '大妈看你 1 秒:"Bless you love. Next stop, get off, go to platform across—Southbound."\n\n你说 thank you。她拍了拍你的手:"We\'ve all done it."\n\n你这一刻明白:UK 大妈跟国内大妈不一样,但温度是同一种。' },
    ],
  },
  {
    id: 'bus_hail_unknown', mode: 'bus', minWeek: 1, maxWeek: 3,
    title: '看着 N°7 公交开过去',
    body: 'Tottenham Court Road 公交站。你查 City Mapper——N°7 还有 1 分钟到。\n\nN°7 真的来了——但它从你面前 slow down 又加速开走。\n\n你愣了 3 秒。下一班 12 分钟后。',
    choices: [
      { label: '问站台另一个人 "怎么招手"',
        effect: { energy: -2, belonging: 5, flag: 'bus_hail_learned' },
        feedback: '一个戴 hijab 的女生看你:"You have to stick your arm out, love. Otherwise it just sails past."\n\n她示范——右手平举。下一班来时你照做。司机点头停下。\n\n你学到一条:**站着不动 = 不上车**。她说:"My first month I missed three buses. Welcome to London."' },
      { label: '默默等下一班 + 再试',
        effect: { energy: -4, stress: 3 },
        feedback: '你等了 12 分钟。下一班来——你这次站近一点。还是开过去。\n\n你最后打了 Uber £11 回家——路上 google 才看到 "wave arm"。\n\n这一课 £11 学的。' },
    ],
  },

  // ─────────────────────────────────────────────────────────────
  // Bus mode · 重复发生类(W2+ repeatable)
  // ─────────────────────────────────────────────────────────────
  {
    id: 'bus_missed_stop_no_bell', mode: 'bus', minWeek: 1, maxWeek: 4,
    title: '不会按 bell · 坐过站',
    body: '你坐 N°7 公交。City Mapper 显示下一站就是 Russell Square。\n\n车到站——但司机没停。你看着站牌从窗外掠过。\n\n你扭头——车上其他人都按过头顶或柱子上的红色 "STOP" 按钮。你刚才没按。',
    choices: [
      { label: '下一站下车 + 反向走回去',
        effect: { energy: -3, stress: 2, flag: 'bus_bell_learned' },
        feedback: '你在下一站按 bell 下车——走了 8 分钟回 Russell Square。\n\n你学到一条:**UK bus 不像国内自动到站停**——必须乘客按 bell 才停。下次你一上车就先找 bell 的位置。' },
      { label: '硬着头皮一直坐到目的地附近',
        effect: { energy: -5, wallet: -2, stress: 4 },
        feedback: '你坐了 4 站到 Holborn 才反应过来按 bell——再 tap out + 反向走 25 分钟回 Russell Square。\n\n下次你 wikipedia 了一下 UK bus 规矩——一个 5 分钟视频解决了一年的困惑。' },
    ],
  },
  {
    id: 'tube_gap_shoe', mode: 'bus', minWeek: 1, maxWeek: 4,
    title: 'Mind the Gap · 鞋卡住了',
    body: 'Bank 站换乘。月台广播一直在说 "Mind the gap between the train and the platform."\n\n你以为只是套话。然后你左脚踩上车——右脚正要跟上时——你的运动鞋卡进月台和车之间 4cm 的缝里。\n\n车门 beep beep——3 秒后关。',
    choices: [
      { label: '猛拉脚 + 鞋掉了',
        effect: { energy: -2, wallet: -45, belonging: 2, flag: 'gap_lesson' },
        feedback: '你把脚拔出来——鞋留在月台缝里。\n\n车门关上启动。你穿着一只袜子站在月台上。\n\n你下楼找 station staff——他笑了:"Happens twice a week, love." 他用一根铁棍把鞋勾上来——但鞋头皮料已经撕开了。\n\n你回家路上买了双新运动鞋 £45。从那天起你**听到 Mind the gap 就低头看**。' },
      { label: '冷静 + 脱掉那只鞋踏进车厢',
        effect: { energy: -1, belonging: 3, flag: 'gap_lesson' },
        feedback: '你脱了那只鞋，光着脚踏进车厢——门 beep 一下关上。\n\n车厢里两个英国本地小哥看了你 1 秒——一个从背包里掏出一双备用袜子递给你:"Mate, that\'s a power move."\n\n你穿着别人的袜子走到 Russell Square。回家后给那只鞋缝补了 30 分钟——勉强还能穿。' },
    ],
  },
  {
    id: 'tube_door_no_wait', mode: 'bus', minWeek: 1, maxWeek: 3,
    title: 'Tube 自动门 · 没等你',
    body: 'Oxford Circus 月台。Central Line 来了。你犹豫了 0.5 秒选哪节车——门 beep 一下关上。\n\n你站在月台上眼睁睁看车开走。下一班 2 分钟后。',
    effect: { energy: -2, stress: 2, flag: 'tube_door_lesson' },
    feedback: '你学到一条:**Tube 门不等人**——国内地铁门关之前会反弹一次给你二次机会，UK 不会。\n\n2 分钟后下一班来。你这次提前 1 秒站到门边，门一开就上车。\n\n这种小的"我适应了"的瞬间，慢慢累积起来才是适应。',
  },
  {
    id: 'tube_sardine_first', mode: 'bus', minWeek: 2, maxWeek: 6,
    title: '8 点高峰 · 第一次挤 Central Line',
    body: '周三早 8:12。你换 Central Line 去 Holborn——你以为还好。\n\n车来了——你看到车厢里的人已经脸贴脸顶在玻璃上。\n\n月台 marshal 喊:"Move down the platform, please. Next train in two minutes."\n\n但你看着下一班一样满。',
    choices: [
      { label: '硬挤进去',
        effect: { energy: -8, stress: 6, belonging: 3, flag: 'tube_rush_initiated' },
        feedback: '你挤了进去——你左肘顶着一个 banker 的公文包，右脸离另一个人的头发 5cm。\n\n3 站 4 分钟。你呼吸都小心翼翼。\n\n下车的时候你想:这是 1872 万人口城市的代价。但你也明白了:**London 通勤 = 全程礼貌的物理暴力**。' },
      { label: '等下一班 (赌人会散开)',
        effect: { energy: -3, stress: 3 },
        feedback: '你等下一班——一样满。第三班还是满。\n\n你最后挤上第四班——已经 8:42。你 9 点的 lecture 迟到 8 分钟。\n\nWhitmore 没说什么——但你坐下时他看了一眼时钟。' },
      { label: '直接打 Uber',
        effect: { wallet: -14, energy: 2, stress: -2 },
        feedback: '你从月台走出去叫 Uber——£14 走 Aldwych。25 分钟到 SOAS。\n\n你这一刻知道:**London 早高峰 8-9 点 Tube 是创伤**。之后你提前 1 小时出门——或者认命打 Uber。\n\n你还没赚到一分钱——这笔 £14 心疼了一周。' },
    ],
  },
  {
    id: 'uber_pickup_lost', mode: 'taxi', minWeek: 1, maxWeek: 4,
    title: '第一次叫 Uber · 司机找不到你',
    body: '你叫了 Uber。App 显示司机 3 分钟到。\n\n你站在公寓楼下。3 分钟过去——app 显示 "Driver arrived"。但你没看到任何车。\n\n司机打电话——你听不清(印度口音 + 街上车声):"Where you mate? I\'m here yeah, where you?"',
    choices: [
      { label: 'WhatsApp 发位置 pin',
        effect: { energy: -1, belonging: 3, flag: 'uber_pin_learned' },
        feedback: '你 WhatsApp 发了 location pin——他 30 秒后开过来。\n\n他下车开门:"Mate, your block has three entrances. App shows the wrong one. Next time send pin first." 你说 thanks。\n\n你学到一条:**Uber pickup 位置 ≠ 你实际门口**——尤其留学生公寓多出口。永远发 pin。' },
      { label: '在街上跑来跑去找',
        effect: { energy: -5, stress: 4, wallet: -3 },
        feedback: '你跑了 6 分钟——他车在隔壁街。\n\n你上车时 meter 已经跑了 £3 等待费。司机不开心，一路他没说话。\n\n这次车费 £18 比正常贵 £3。你也明白了:**Uber 在英国是城市不是家**——一切要主动核对。' },
    ],
  },
  {
    id: 'uber_surge_rain', mode: 'taxi', minWeek: 4, maxWeek: 12,
    title: '雨天 Uber · 价格 ×3.2',
    body: '周三晚 6:15。SOAS lecture 散场——你走出主楼，大雨。你没带伞。\n\n你打开 Uber——平时 £8 的距离今天显示 **£26**。app 上闪一行字:"Prices are higher due to high demand."',
    choices: [
      { label: '咬牙叫了',
        effect: { wallet: -26, energy: 3, stress: 2, flag: 'surge_learned' },
        feedback: '你叫了——8 分钟到家。司机:"Yeah love, every wet evening it\'s like this. 5 PM to 8 PM avoid Uber if you can."\n\n你回家衣服干。但你看着账户 £26 蒸发——这够你 3 顿 Mei\'s 饭。\n\n你学到一条:**London 下雨晚高峰 Uber surge 3x 起步**。从此你包里常备一把 Sainsbury\'s £4 折叠伞。' },
      { label: '等 30 分钟看 surge 降下来',
        effect: { wallet: -12, energy: -3, stress: 4 },
        feedback: '你在 SOAS 大厅躲雨 30 分钟。surge 降到 1.5x = £12。你叫了。\n\n但你 lecture 后空腹——8 点才回家，已经饿到头晕。回家煮泡面 + 倒头睡。\n\n你也学到一条:**surge 一般 30-60 分钟会降**——前提是你不急。' },
      { label: '冒雨走回家',
        effect: { energy: -10, stress: 5 },
        feedback: '你冲进雨里走了 25 分钟到家。\n\n到家全身湿透——hoodie 滴水，鞋里全是水。\n\n第二天你嗓子疼。你想:那 £26 我刚才省了——但 NHS 看病要预约，Boots Lemsip £6，essay 拖了一周。\n\n这是省钱陷阱——下次 £26 你就叫了。' },
    ],
  },

  // ─────────────────────────────────────────────────────────────
  // Bus mode · 重复事件
  // ─────────────────────────────────────────────────────────────
  {
    id: 'tube_signal_lost', mode: 'bus', minWeek: 2, repeatable: true,
    title: 'Tube 进 tunnel · 信号全失',
    body: '你在 Tube 上刷小红书——画面一卡。"No Signal"。\n\n你抬头——周围 30 个人全在低头看手机。一半的人也卡住了，但他们不抬头——他们已经习惯了。',
    effect: { energy: -1 },
    feedback: '你跟着大家继续盯着 frozen 的画面。3 分钟后出 tunnel，所有 notification 一齐爆——但你已经过了那个想看的瞬间。\n\n你学到一条 London 通勤族的常识:**Tube 上别刷直播内容，提前下载好**。',
  },
  {
    id: 'bus_top_deck_first', mode: 'bus', minWeek: 1, maxWeek: 10,
    title: '第一次坐双层巴士上层',
    body: '你上了一辆 N°15 公交——发现下层全是人。\n\n你犹豫了 2 秒，跟着前面一个英国男生爬到上层。\n\n上层前排空着——你坐了最前排正中间。透过玻璃，整条 Strand 在你眼前展开。',
    effect: { energy: 5, belonging: 6, flag: 'top_deck_first' },
    feedback: '你拍了一段视频发朋友圈——"我现在坐在 Routemaster 上层第一排"。15 个赞。\n\n你这一刻明白:**伦敦双层巴士前排上层 = 城市观光最便宜的票**。之后你专门挑双层坐。',
  },
  {
    id: 'tube_busker_underground', mode: 'bus', minWeek: 4, repeatable: true,
    title: 'Tube 换乘通道 · Busker',
    body: 'Oxford Circus 换乘通道。一个 25 岁的男生抱吉他唱 Coldplay《Fix You》。\n\n他面前的吉他盒里——10 张 £5 + 几个硬币 + 一张 Pret loyalty card(谁放的)。\n\n你路过，他冲你笑了一下。',
    choices: [
      { label: '停下 + 听完整段 + 给 £2',
        effect: { wallet: -2, energy: 3, belonging: 4 },
        feedback: '你站在那里 4 分钟听完。其他通勤的人潮从你身边流过——你是唯一停下的那一个。\n\n他唱完冲你点头。\n\n你这一刻明白:**伦敦 Tube busker 都要通过 TfL 试镜**——这首歌他练了 100 次才能在这里唱。' },
      { label: '走过去 + 没给钱',
        effect: { energy: 1 },
        feedback: '你跟着人潮走过去。歌声在你身后慢慢淡掉。\n\n你回家那晚突然想起那段旋律——但你忘了他唱的是什么。' },
    ],
  },
  {
    id: 'bus_old_lady_seat', mode: 'bus', minWeek: 3, repeatable: true,
    title: '让座给 65 岁老太太',
    body: '上班高峰 N°7 公交。下层挤满。\n\n一个 65 岁的老太太上车——她抓着扶杆站着。你坐的是 priority seat。',
    choices: [
      { label: '站起来让座',
        effect: { energy: -2, belonging: 6 },
        feedback: '你站起来:"Please, have a seat."\n\n她笑:"Oh thank you dear, what a gentleman/lady." 她坐下。\n\n下一站她下车前拍了拍你的手:"Bless you sweetheart."\n\n你回家那晚想起她——这种细小的温度是英国的好处之一。' },
      { label: '装看手机不动',
        effect: { energy: 1, belonging: -3 },
        feedback: '你低头玩手机。但她站在你面前，你能感觉到。\n\n第 3 站旁边一个 white teenager 让了座——老太太眼睛扫了你一下。\n\n你下车那一刻就明白:她记住你了。' },
    ],
  },
  {
    id: 'tube_drunk_friday', mode: 'bus', minWeek: 6, repeatable: true,
    title: '周五晚 11 点 · Central Line 一节满是醉鬼',
    body: '周五晚 11:30。你从 Oxford Circus 上 Central Line 回家。\n\n整节车 30 个人，20 个明显喝了——一个 west end 散场的中年男在大声跟没人讲他 wife 的事;两个本科女生穿 club 装互相搀扶;一个 50 岁 city banker 西装领带歪着睡过去。\n\n你找了个角落座位。',
    choices: [
      { label: '戴上耳机闭眼 18 分钟到家',
        effect: { energy: -3, stress: 2 },
        feedback: '你 noise-cancel + 闭眼。\n\n但中年男一直在响，你能透过 ANC 听到他反复的 "she said... she said..."。\n\n你回家想:伦敦周五晚的 Tube 是一种 lonely 的民俗博物馆——所有人都在那里，但所有人都自己一个人。' },
      { label: '换下一节车厢',
        effect: { energy: -2, belonging: -1 },
        feedback: '你下一站走出去换下一节——下一节也差不多，只是醉鬼换成不同 demographic。\n\n你最后蹲在车头驾驶舱旁边的扶杆——那里至少安静。' },
    ],
  },

  // ─────────────────────────────────────────────────────────────
  // Taxi mode · 司机攀谈类
  // ─────────────────────────────────────────────────────────────
  {
    id: 'taxi_chatty_cabbie', mode: 'taxi', minWeek: 1, repeatable: true,
    title: 'Black Cab 司机讲 1992 年',
    body: '你叫了 Uber——结果来了一辆 Black Cab(同一个 app 也接 Black Cab)。\n\n司机 60 多岁，看你后视镜:"Where you from love?" 你说 China。\n\n他点头:"Beijing? Shanghai? I was in Hong Kong in 1992. Different time."',
    effect: { energy: 2, belonging: 5 },
    feedback: '他跟你讲了一路他 1992 年在香港的事——他做 RAF helicopter，handover 那年。你听了 20 分钟没说几句话。\n\n下车他不收 tip:"Welcome to London love. You\'ll like it here, eventually."\n\n你这一刻明白:**Black Cab 司机都是历史口述博物馆**。打车贵但有时候值。',
  },
];
