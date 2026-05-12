export const STRANGER_EVENTS = [
  // ===== Cherry「学姐」（代写党 · 钓鱼身份 · 2-stage reveal）=====
  // 现实背景：境内运营，群里加好友 → 私聊建立信任 → deadline 前推销代写。
  // 头像永远是精修甜美女生图（盗图）；从不约线下；语气过分热情。
  {
    id: 'cherry_normal_1', strangerId: 'cherry_daixie', weeksAfter: 3,
    title: 'Cherry 私信发"经验贴"',
    body: 'Cherry 给你私信："学弟 / 学妹 我整理的 30000 字经验贴：reading list + Whitmore 喜欢什么 framing + tutorial 不能犯的 5 个错。免费给你 ❤️" 后面跟一个 Notion 链接。\n\n你顺手翻了她朋友圈——她每条都很认真：图书馆灯下、咖啡杯、笔记本。看起来就是个成绩好的 Y2 学姐。',
    choices: [
      { label: '点开看 + 道谢', effect: { energy: -1, academic: 2, belonging: 2 },
        feedback: '你点开 Notion——内容确实详尽，全是 Y2 真实知识。你回："谢谢学姐 救命。" Cherry 立刻回："客气啦 我们这届都是这么过来的 有问题随时问我 ❤️"\n\n你想：怎么会有这么热心的学姐。' },
      { label: '"谢谢" 但没点', effect: { belonging: 1 },
        feedback: '你客气回了一句没真打开。Cherry 回了一句"嗯嗯有空看 ❤️"。' },
    ],
  },
  {
    id: 'cherry_pitch', strangerId: 'cherry_daixie', weeksAfter: 16,
    title: 'Cherry 突然私信',
    body: 'Week 19。期末 essay deadline 还有 8 天。Cherry 突然发来一长串：\n\n"学弟 / 学妹 不知道方便不方便问—— 你那个 essay 进度怎么样啦？我之前帮我室友过了一篇 distinction 我有个 native speaker 朋友 PhD 在读 3000 字 £180 包改到你满意 Turnitin 0% 完全不留痕迹 ❤️ 不收定金 出稿先看 你信我 hhh"\n\n后面附一张精致的价目表截图 + 一张所谓"成功案例" PDF 缩略图。你截屏她头像放大放进 Google 图片反查——是某个无关韩国 Instagram 网红盗的。',
    choices: [
      { label: '"什么意思？我自己写。" + 拉黑', effect: { energy: -2, academic: 4, belonging: 6, flag: 'daixie_refused' },
        feedback: '你发完那句话直接拉黑 Cherry。\n\n那 30000 字 Notion 是 funnel。3 个月铺垫，就为这一刻。她"学姐"人设、朋友圈、热心——全是脚本。\n\n第二天 tutorial Whitmore 在白板上写 "Original thinking is not a luxury. It is the only thing." 你一下子坐直了。' },
      { label: '截图发群挂出来', effect: { energy: -5, belonging: 3, flag: 'daixie_reported', npc: { aditi: 1 } },
        feedback: '你把 Cherry 的私信 + 反查头像截图发到群里：「@所有人 这个 Cherry 是代写党。头像盗的某 IG 网红。学妹 / 学弟 注意。」\n\n狗哥：靠 我也加过她 当时我以为是 hr 学姐\n@Lily：天 我朋友圈她还给我点赞过 ✨ 现在删\n上岸了的姐：每年 deadline 前都有这种。识别要点：免费送大量"经验贴" + 私聊不在群里说话 + 朋友圈定时发。\n新生小王：???? 我前天还跟她说"谢谢学姐"\n凯泽：CSSA 群主已经踢了\n\nAditi 私聊你："Brave of you. I had four messages like this last semester. Different name, same playbook."' },
      { label: '"价格能低吗"（探）', effect: { energy: -3, belonging: -4, flag: 'daixie_tempted' },
        feedback: '你回了一句"价格能再商量吗"。Cherry 立刻发来一个升级价目表 + 微信支付码 + 试稿 PDF。\n\n你看着那张支付码 30 秒。然后退出聊天。\n\n你最后没付。但你心里有点虚——你为什么会"问价"？是 deadline 还是别的？' },
      { label: '"不需要 谢谢"（礼貌拒绝）', effect: { belonging: 0, flag: 'daixie_refused' },
        feedback: '你客气回了一句。Cherry 立刻回 "好的 学弟 / 学妹 加油 有需要随时找我 ❤️"——好像什么都没发生。\n\n一周后她从群里消失（被踢？换号？）。你后来听说她另外开了 3 个号在不同 CSSA 群里发同一套 funnel。' },
    ],
  },

  // ===== 小李（传媒）=====
  {
    id: 'xl_vlog_help', strangerId: 'xiao_li', weeksAfter: 5,
    title: '小李来求拍摄帮忙',
    body: '小李群里 @你："学弟/学妹 救救命 我想做一个 Soho 美食 vlog 但我不会运镜 你能不能陪我拍一下午 请你吃 Chinatown 所有好吃的"',
    choices: [
      { label: '"行 周六见"', effect: { energy: -8, wallet: 0, belonging: 12, flag: 'helped_xl' },
        feedback: '你陪她走了 6 家店，吃了 3 份不一样的食物。她自己其实只啃了一口 falafel——"我得忌口 镜头里要瘦"。\n\n临走时她给了你 £30："请你吃晚饭。我知道这个钱不多 但我现在能给的就这么多。" 你愣了一下。原来她不是表面那么"精致"——她在养自己。' },
      { label: '"我没空 抱歉"', effect: { belonging: -2 },
        feedback: '小李在群里冷下来三周。你后来听说她自己拍了。' },
    ],
  },
  {
    id: 'xl_brand', strangerId: 'xiao_li', weeksAfter: 12, requireFlag: 'helped_xl',
    title: '小李：要不要一起做 IP',
    body: '小李突然给你发消息："那次拍的视频火了 80 万播放。小红书上有品牌找我合作。我一个人忙不过来。要不要做我搭子？分成五五开。"',
    choices: [
      { label: '"试试看"', effect: { wallet: 200, energy: -10, belonging: 8, flag: 'xl_brand_partner' },
        feedback: '你接了第一个单子。化妆品品牌，£400，你拿一半。你帮她拍了 3 天。账户里多出 £200。\n\n你想：原来在伦敦也可以这样赚钱——不是端盘子，是用脑子。' },
      { label: '"我得专心学业"', effect: { academic: 4 },
        feedback: '小李说"理解"。她后来真的火了，6 个月后 30 万粉。你偶尔刷到她的视频，里面有你拍的那个下午。' },
    ],
  },

  // ===== 阿强（电子工程）=====
  {
    id: 'aq_marriage', strangerId: 'a_qiang', weeksAfter: 4,
    title: '阿强第一次打了字',
    body: '群里阿强从来只发表情包。但今天他突然 @ 你：\n\n"哥们 / 姐们 我下周飞回去相亲 我妈安排的 我没见过对方 你说我去吗"',
    choices: [
      { label: '认真回："去看看 见一面又不会怎么样"', effect: { energy: -3, belonging: 10, flag: 'aq_advised' },
        feedback: '阿强发了一长串解释（破天荒）："我妈病了 想抱孙子。我也不知道我自己想要什么。" 你回了 200 字。\n\n他最后说："我从来没听别人这么跟我说话。谢了。"' },
      { label: '发个表情包"加油 [doge]"', effect: { belonging: 1 },
        feedback: '他回了 6 个表情包。然后没下文了。' },
    ],
  },
  {
    id: 'aq_engaged', strangerId: 'a_qiang', weeksAfter: 10, requireFlag: 'aq_advised',
    title: '阿强订婚了',
    body: '阿强突然在群里发了一张照片——他和一个戴眼镜的女生站在一起，桌上有戒指。\n\n"订婚了。你那次跟我说的话我记着的。"',
    choices: [
      { label: '"恭喜 婚礼记得叫我"', effect: { belonging: 8, flag: 'aq_wedding_invite' },
        feedback: '阿强回："必须的。"\n\n半年后他真的把婚礼请柬发到了群里。山东老家，端午。"你要是回国能赶上 我接你机场。"\n\n你看到那条消息坐了 1 分钟没回。你想这就是中国留学生圈——一切都荒诞，但情谊都是真的。' },
      { label: '"恭喜兄弟 / 姐妹"', effect: { belonging: 4 },
        feedback: '阿强回了一个鞠躬的表情。' },
    ],
  },

  // ===== 婷婷（KCL · 经济）=====
  {
    id: 'tt_lecture', strangerId: 'tingting', weeksAfter: 6,
    title: '婷婷约你听讲座',
    body: '婷婷发消息："我们 KCL 这周有个 IMF 经济学家的 lecture 你要不要来？我可以带一个外校 plus one。"',
    choices: [
      { label: '去', effect: { energy: -6, academic: 8, belonging: 10, flag: 'tt_lecture_attended' },
        feedback: '你去了。Strand 校区比你的学校豪华。讲座 2 小时，你听懂了 70%。\n\n讲完婷婷带你认识她的几个朋友——一个 LSE 的女生，一个 Imperial 的男生。你们一起在 The Wellington 喝了一杯。\n\n你回家路上想：原来伦敦有那么多平行的世界。' },
      { label: '"我那天没空"', effect: { belonging: -2 },
        feedback: '婷婷回了一个 "ok 下次"。下次你们没再约过。' },
    ],
  },
  {
    id: 'tt_offer', strangerId: 'tingting', weeksAfter: 14, requireFlag: 'tt_lecture_attended',
    title: '婷婷拿到 offer',
    body: '婷婷发消息："我拿到了 Goldman Sachs 的 offer。我想请你吃饭——你那次愿意来，对我意义很大。"',
    choices: [
      { label: '去', effect: { energy: -3, wallet: -15, belonging: 15, flag: 'tt_offer_dinner' },
        feedback: '她带你去 Borough Market 一家不算贵的西西里小馆——AA 制，人均 £35。窗外是 Southwark 的雨。\n\n她说："我面试的时候紧张到哭。后来我想起你那次跟我朋友们说话的样子——你不会装。我学了你那一点。"\n\n你愣了。原来你也教过别人东西。' },
      { label: '"恭喜 改天再聚"', effect: { belonging: 3 },
        feedback: '婷婷说"好"。下次没真的约。' },
    ],
  },

  // ===== 老周（40 岁 · 第二次留学）=====
  {
    id: 'lz_essay_help', strangerId: 'lao_zhou', weeksAfter: 5,
    title: '老周求助 essay',
    body: '老周私聊你："小同学 我有个 essay 写得很差 你能不能帮我改改？我儿子高考完了 我想这次必须毕业。我请你吃饭。"',
    choices: [
      { label: '认真改', effect: { energy: -10, academic: 3, belonging: 12, flag: 'helped_zhou' },
        feedback: '你改了 3 小时。老周的英文比你想象中差——他大学是 80 年代的，那时候没有英语高考。\n\n他后来交了。两周后他跑来 Mei\'s 找你："过了！71 分！我跟我儿子说 我也行。" 然后他哭了。\n\n你看着这个 40 岁的男人哭，自己也红了眼。' },
      { label: '"我自己 essay 都写不完"', effect: { belonging: -3 },
        feedback: '老周说"理解"。一周后他在群里说他挂了。' },
    ],
  },
  {
    id: 'lz_wife_visit', strangerId: 'lao_zhou', weeksAfter: 11, requireFlag: 'helped_zhou',
    title: '老周的妻子来伦敦',
    body: '老周："我老婆来看我 待 5 天。她想见见你 她说 \'那个帮老周改 essay 的小同学\'。我们家请你吃饭 周日。"',
    choices: [
      { label: '去', effect: { energy: -5, wallet: -10, belonging: 18, flag: 'lz_wife_dinner' },
        feedback: '老周妻子 38 岁，话不多。她在老周临时租的 Airbnb 厨房里做了两道菜——一锅酸菜炖排骨 + 一盘凉拌豆腐皮。\n\n吃饭中段她抬头看了你一眼："谢谢你帮他改论文。" 然后又低头吃饭。\n\n你说不出话来。你想：原来很多关心是从一个不善表达的人手里递过来的。' },
      { label: '"我那天有事"', effect: { belonging: -3 },
        feedback: '老周说"没事 下次"。但他妻子飞回去之后，他在群里安静了很久。' },
    ],
  },

  // ===== 大江（健身）=====
  {
    id: 'dj_run', strangerId: 'da_jiang', weeksAfter: 4,
    title: '大江约晨跑',
    body: '大江发消息："明天早上 6 点 Hyde Park 跑步 我在 Speakers\' Corner 等你 不来当孬种"',
    choices: [
      { label: '去', effect: { energy: 8, belonging: 6, flag: 'dj_run_partner' },
        feedback: '6 点的 Hyde Park 凉得要命。大江已经跑了 5 公里。你跟着他跑了 3 公里就快不行了。\n\n他停下来等你："喘 没事 今天就这样 下次再来。" 然后他递了一瓶水。\n\n你跟他跑了 4 周。第四周你能跑 5 公里不停了。' },
      { label: '"早上起不来"', effect: { belonging: -1 },
        feedback: '大江发了"行 看你自己"。然后他没再叫过你。' },
    ],
  },
  {
    id: 'dj_marathon', strangerId: 'da_jiang', weeksAfter: 13, requireFlag: 'dj_run_partner',
    title: '大江参加马拉松',
    body: '大江："我下周日跑 London Marathon。第 12 mile 在 Tower Bridge 那边 你能不能去给我加油？我谁都没邀请 就你"',
    choices: [
      { label: '去 Tower Bridge 等他', effect: { energy: -3, belonging: 15, flag: 'dj_marathon_cheer' },
        feedback: '你举着自己手写的牌子站在路边——"大江！加油！"\n\n他跑过来时已经累得不行。看到你那一刻他的眼睛亮了。他冲过你时大喊"哥们/姐妹儿 谢谢！" 然后他真的跑完了 42 公里。\n\n你那块牌子被他留下来了。"我儿子以后看。"' },
      { label: '"那天我有事"', effect: { belonging: -2 },
        feedback: '大江发了一个"OK"。他后来在朋友圈发完赛照片，没艾特任何人。' },
    ],
  },

  // ===== 露露（艺术）=====
  {
    id: 'll_exhibit', strangerId: 'lulu', weeksAfter: 8,
    title: '露露的画展',
    body: '露露发消息：\n\n"我有 3 幅画在 Goldsmiths 学生展上。下周三开幕。我没邀请别人。但你那次在 Tate 站在 Rothko 前的样子... 我想你应该看看。"',
    choices: [
      { label: '去', effect: { energy: -3, belonging: 14, flag: 'attended_lulu_show' },
        feedback: '你去了。露露的画——三幅都是大幅的、抽象的、暗色调的。她站在你旁边，没说话。\n\n5 分钟后她小声说："这一幅是我妈走的那年画的。"\n\n你转过头看她。她眼睛是红的。她说："谢谢你来。"' },
      { label: '"那天我有事 抱歉"', effect: { belonging: -3 },
        feedback: '露露回："没事 我懂。" 但你知道你错过了什么。她后来在群里再也没主动跟你说过话。' },
    ],
  },
  {
    id: 'll_gift', strangerId: 'lulu', weeksAfter: 15, requireFlag: 'attended_lulu_show',
    title: '露露要送你一幅画',
    body: '露露："我搬家 整理画室 想送你一幅小的。是我去年画的 一个雾中的伦敦塔桥。我觉得你会懂。"',
    choices: [
      { label: '收下', effect: { belonging: 12, flag: 'lulu_painting' },
        feedback: '你去她工作室拿画。30 cm × 40 cm。颜色是灰白蓝的。看起来安静得让人想哭。\n\n她说："这是我画过最孤独的一幅。但你来看过的那次让我觉得 也许孤独的画也有人懂。所以我想给你。"\n\n你后来把这幅画带回了国。它现在挂在你家客厅。' },
      { label: '"太贵重了 我不能要"', effect: { belonging: 4 },
        feedback: '露露说"那好吧"。但她说话的语气你听出了什么。你回家路上有点后悔。' },
    ],
  },

  // ===== Aisha (巴基斯坦 · 穆斯林) =====
  {
    id: 'aisha_ramadan', strangerId: 'aisha', weeksAfter: 4,
    title: 'Aisha · "斋月期间一起复习"',
    body: 'Aisha 私聊："Hey, Ramadan started this week. I won\'t be eating between sunrise and sunset. Library group room booking 你有的话能不能借我用——晚上比较好集中精力？"\n\n你 google 了一下：英国留学生穆斯林斋月——白天不吃不喝，晚上 8:30 后 break fast。',
    choices: [
      { label: '"我下周日早 7am 帮你抢一周 group room"', effect: { energy: -3, belonging: 12, flag: 'aisha_friend' },
        feedback: 'Aisha 一周的 study sessions 你都给她 cover。\n\n第二周你陪她 break fast 一次——她拿出枣 + 牛奶（先吃这两个，是 sunnah）。"This is how my dad taught me." 她递了一颗给你。\n\n你吃了。这是你这一年第一次跨文化"分享一个 ritual"——不是观光，是参与。' },
      { label: '"Sorry I need it for my own group"', effect: { belonging: -2 },
        feedback: 'Aisha 说"完全理解 谢了"。然后她自己去抢——没抢到。\n\n下次她再不会问你了。' },
    ],
  },
  {
    id: 'aisha_eid_invite', strangerId: 'aisha', weeksAfter: 14, requireFlag: 'aisha_friend',
    title: 'Aisha · Eid 邀请',
    body: '4 月。Eid al-Fitr——斋月结束的庆祝节。\n\nAisha 邀请你："Eid is Sunday. We\'re having a family lunch in Hounslow. My mum specifically said \'bring your friend\'. Are you free?"\n\n这是英国巴基斯坦家庭最重要的一天。',
    choices: [
      { label: '去 Hounslow', effect: { wallet: -8, energy: 5, belonging: 22, flag: 'eid_lunch' },
        feedback: 'Aisha 家是 4 房联排 — 客厅挤了 25 个亲戚。她妈妈给你 forehead kiss + 用乌尔都语祝福（Aisha 翻译："may you find your way home wherever you go"）。\n\n午餐是 biryani + samosas + halwa。所有人都问"are you single? we have a cousin..."（你已习惯这种文化）。\n\n临走时 Aisha 妈妈塞给你一袋自制 sweets 和一个绣花布袋。\n\n你坐 District Line 回 Soho 时眼眶红的——你想：这一天我跟一个我半年前不认识的 housemate 的家人吃了她们一年最重要的饭。' },
      { label: '"那天我有论文 抱歉"', effect: { belonging: -5 },
        feedback: 'Aisha 说 "no worries"。但她不会再邀请第二次。\n\n你之后偶尔在 group chat 看到她发 Eid 照片——25 个家人 around 桌子。你想：那个空椅子可能本来是你的。' },
    ],
  },

  // ===== Marcus (Black British) =====
  {
    id: 'marcus_essay_crit', strangerId: 'marcus', weeksAfter: 5,
    title: 'Marcus · 帮你看 essay',
    body: 'Marcus 在 group chat 里："yo whoever wants their essay torn apart constructively, I\'m offering free marks tonight. PhD students need warm-up exercises."\n\n你 DM 了他你的 essay。3 小时后他回了一份 8 页评注 PDF——比 Whitmore 都狠。',
    choices: [
      { label: '认真改 + 谢他', effect: { academic: 8, energy: -5, belonging: 14, flag: 'marcus_mentor' },
        feedback: '你 fully revise 一次。Marcus 看了说 "yeah this is a different essay now". \n\n他喝着 Tesco £4 的 wine 说："I had to teach myself a lot of this stuff. PhD\'s aren\'t taught how to write—we just survive. So when I see someone trying, I help."\n\n他问你"where you from?" 你说 China。他说 "yeah I\'ve never been but I want to. My grandma\'s from Jamaica and she said \'we are all just one big diaspora\'." \n\n你想：原来 diaspora 这个词不是只对中国人。' },
      { label: '只挑评注里 1 个改', effect: { academic: 2, belonging: -1 },
        feedback: '你只 fix 了拼写。Marcus 看了不说话。\n\n下次他不会再给你看 essay 了——但他会给别人看。这是 mentorship 的代价：你只用 5%，他不会给 100%。' },
    ],
  },
  {
    id: 'marcus_microagression_advice', strangerId: 'marcus', weeksAfter: 12, requireFlag: 'marcus_mentor',
    title: 'Marcus · 你跟他吐槽 "where are you really from"',
    body: '你在 The Crown 跟 Marcus 喝啤酒。你跟他讲 tutorial 那次 tutor 让你"代表中国"。\n\nMarcus 听完 5 秒。然后说："Welcome to the club, mate."\n\n他放下啤酒："I\'ve been British for 31 years. Born in Hackney. People still ask me \'where are you really from\'. You know what I learned? You don\'t owe them an answer."',
    effect: { energy: 3, belonging: 14, flag: 'marcus_solidarity' },
    feedback: '他说："The trick isn\'t to find the perfect comeback. The trick is to stop carrying it home with you."\n\n你看着他喝完一杯 Guinness。\n\n你想：这一年你在英国遇到的中国前辈、同学、CSSA 都不会跟你这样说。Marcus 跟你不一样——但 Marcus 跟你又同样。\n\n这是 cross-diaspora friendship 第一次让你感受到——你不是 alone in this。',
  },

  // ===== Park (韩国 · LGBT) =====
  {
    id: 'park_concert', strangerId: 'park', weeksAfter: 6,
    title: 'Park · 邀你去 concert',
    body: 'Park 给你发链接：KCL 音乐学院学生 concert，£0 学生票，Park 自己上台演奏 violin。"Friday 7pm. Come if you can. I might be terrible."',
    choices: [
      { label: '去看 concert + 鼓掌', effect: { energy: -3, belonging: 8, flag: 'park_concert' },
        feedback: 'Park 演奏 Bach Partita——你不懂技术但你听出 ta 真的在 nail 那段。\n\n散场 ta 跑过来："Oh thank God you came, my parents flew in from Seoul and they don\'t speak English well."\n\n你跟 ta 父母 broken 韩英中三语聊了 30 分钟。Ta 妈妈一直握着你的手。\n\n回家 Park DM："Thank you for being kind to my parents. They don\'t fully accept I\'m gay yet—but seeing me have a friend who treats me normally helps them more than anything I could say."' },
      { label: '"那天有事 抱歉"', effect: { belonging: -2 },
        feedback: 'Park 没回。第二天在 group chat 装作没事。\n\n你之后才知道——那天是 ta 家长 5 年来第一次飞过来看 ta。Ta 邀请的人不多。' },
    ],
  },
  {
    id: 'park_outing_dad', strangerId: 'park', weeksAfter: 16, requireFlag: 'park_concert',
    title: 'Park · 跟你聊 coming out',
    body: '深夜 1 点。Park 给你 voice msg："Sorry to bother you. My dad just called. He saw a video of me on Instagram with my boyfriend. He said \'come home, we\'ll figure this out\'. I think \'figure this out\' means convert me. I don\'t know what to do."',
    choices: [
      { label: '"You don\'t have to go. You\'re an adult."', effect: { energy: -3, belonging: 12, flag: 'park_supported' },
        feedback: 'Park 哭了 5 分钟说不出话。然后："I know. But he\'s my dad."\n\n你说"that doesn\'t mean he gets to decide who you are."\n\n你们 voice 到 4am。Park 没回韩国。Ta 留在伦敦——一年后 ta 跟你说："That night was the first time someone said \'you\'re an adult\' to me. My Korean friends would have said \'family is everything, go\'."\n\n你想：跨文化 friendship 的另一种价值——给对方一个不在 ta 文化默认脚本里的选项。' },
      { label: '"Your family loves you, you should go talk"', effect: { belonging: -3 },
        feedback: 'Park 没回。第二天 ta 删了 Instagram 上跟 boyfriend 的所有视频——但没回韩国。\n\n你们之后 group chat 还在但你们不再深聊。Ta 学了一个 lesson——你不是 safe 的人 to talk about this。' },
    ],
  },
];
