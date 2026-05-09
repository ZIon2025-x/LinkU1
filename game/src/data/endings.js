// Data-driven endings table. The original game used a long if/else chain in
// generateEnding(); we capture the exact same priority order here.
//
// Each entry: { id, condition: (state) => bool, ending: { title, subtitle, text } }
// resolveEnding() walks the list top-down and returns the first match.
//
// Convention: `state.flags`, `state.stats`, `state.storyProgress`, `state.npcRel` are present.

export const ENDINGS = [
  // ============================================================
  // Tier 0 — 父母来过 + 学业 ≥ 55  (heaviest single-flag ending)
  // ============================================================
  {
    id: 'parents_visited_academic',
    condition: ({ flags, stats }) => flags.parents_visited && stats.academic >= 55,
    allowLink2UrEcho: true,
    ending: {
      title: '我让他们看到了', subtitle: 'What They Saw',
      text: '毕业典礼那天，爸妈又来了。\n\n这次他们不再怯生生的。他们坐在你旁边，跟周围的英国家长点头微笑。妈妈穿了一件你以前没见过的红色外套。爸爸打了领带——他这辈子领带次数没超过 5 次。\n\n你穿学袍走过台子的时候，听到台下传来一声不太响但很穿透的"哎哎哎"——是你妈，她不知道毕业典礼不能喊。\n\n你没回头。但你笑了。\n\n爸爸把你穿学袍的照片发到了家族群。你姑妈秒回："这孩子有出息了。" 你姑父："恭喜恭喜。"\n\n你爸罕见地回了一句话——比他过去一年发的所有朋友圈加起来都长：\n\n"不是这孩子有出息了。是这孩子让我和她妈这一辈子值了。"\n\n群里安静了 30 秒。\n\n然后你妈妈发了一句："老头子。煽什么情。" 后面跟了一个 doge 表情。\n\n你看着这条消息看了 5 分钟。然后你笑了。然后你哭了。\n\n你想起一年前你在 Heathrow T3 接他们时妈妈手里那袋你 8 岁时最爱吃的饼干。\n\n你想起你爸抚摸学校牌匾时偷偷擦的那滴泪。\n\n你想起他说"对不起 这一年让你一个人"。\n\n你心里说：爸 不是你对不起我。是你给了我这一年。\n\n谢谢你们。',
    },
  },

  // ============================================================
  // 隐藏专属结局 — Link2Ur 内部员工
  // 条件极高：评分 ≥ 4.8 + 接单 ≥ 30。比 sarah_double 优先级更高。
  // ============================================================
  {
    id: 'link2ur_employee',
    condition: ({ link2urRating = 0, link2urCompletedCount = 0 }) =>
      link2urRating >= 4.8 && link2urCompletedCount >= 30,
    ending: {
      title: '内部员工 · 03 号', subtitle: 'Employee #003',
      text:
        '毕业三年后。你在 Link2Ur 伦敦总部上班——员工编号 003。\n\n' +
        '当年面试你的运营总监原话："我们后台数据看了你那一年。30+ 单 4.9 评分。'
        + '更稀奇的是——你接的 18% 是亏本单（路费比报酬高）。系统标过你 7 次"经济不理性"。'
        + '我们就想见见这个人。"\n\n你笑了。你没解释——但你心里知道。\n\n'
        + '那不是不理性。那是当时的你 22 岁，刚从 Heathrow 走出来 8 个月，被一个 Aisha / 一个 CSSA 学姐 / 一个 Mark 接住过——'
        + '你只是想替系统记住"被接住"是什么感觉。\n\n'
        + '现在你在 Link2Ur 主管"新生互助"模块的产品设计。你写过的一个 spec 标题叫'
        + '《如何让一个刚下飞机的孩子在 8 个月内觉得 "我没有掉下去"》。\n\n'
        + '没人在公司内部 push 这个项目，但 CEO 看完 spec 当天给你升了 senior。'
        + '她说："我们没法保证每个新生都有一个 Mei 姐。但我们至少可以保证有一个 app。"\n\n'
        + '你下班走出 Old Street 站。伦敦的 5 月，天还亮着。\n\n'
        + '你想起一年前那个在 Bloomsbury Surgery 排队取药的下午——\n\n'
        + '那时候你不知道，原来你后来会站在桌子的另一头。',
    },
    allowLink2UrEcho: false,  // 这个 ending 本身就是 Link2Ur 主线，不再加 echo
  },

  // ============================================================
  // Tier 1 — 双 flag 组合（最稀有）
  // ============================================================
  {
    id: 'sarah_double',
    condition: ({ flags }) => flags.cotswolds_xmas && flags.eurotrip_sarah,
    allowLink2UrEcho: true,
    ending: {
      title: '一辈子的朋友', subtitle: "Sarah's Best Mate",
      text: '毕业三年后。你回伦敦参加 Sarah 的婚礼。\n\n她穿着一身简单的白裙，在 Cotswolds 那栋你过过圣诞的房子里。她妈把你当自家孩子一样抱了一下："Welcome home, dear."\n\n仪式上 Sarah 念誓词的时候转过头看了你一眼，笑了。后来婚礼录像里你看到那一秒——她笑着对你眨了眨眼，像在说"你看，我们做到了"。\n\n你在伴娘/伴郎致辞里说：「I came to England not knowing anyone. Sarah taught me what it meant to have a friend here. And now her family is my family.」\n\nSarah 哭了。她妈也哭了。整个 Cotswolds 都哭了。\n\n你想起那个第一次去 Pub 不敢点酒的自己，觉得他离这里好远。',
    },
  },
  {
    id: 'aditi_double',
    condition: ({ flags }) => flags.visited_india && flags.easter_aditi_pact,
    allowLink2UrEcho: true,
    ending: {
      title: '一封孟买来的信', subtitle: 'Letter from Mumbai',
      text: '毕业一年后。你在多伦多工作。一个寻常的周二，你收到一封手写的信。\n\nAditi 用了印度邮票，蓝色的航空信封。她写：\n\n"Dad passed last month. He held on for a long time, and I think a part of why he did was because he wanted to thank you again, in person. He didn\'t get to. But he wanted you to know.\n\nI got engaged. His name is Vikram. He works in Bangalore. The wedding is in March. I want you to come.\n\nDo you remember what you said in the library at 2am? \'You have me.\' I remembered that every day this year. Now it\'s my turn.\n\nYou have me. Always.\n\n— A."\n\n你坐在多伦多的小公寓里读了三遍。\n\n然后你订了去孟买的机票。',
    },
  },
  {
    id: 'mei_double',
    condition: ({ flags }) => flags.mei_family && flags.mei_manager,
    ending: {
      title: 'Lucky Star 的少东家', subtitle: "Auntie's Heir",
      text: '毕业那天 Mei 姐没去你的毕业典礼。"姨忙着开第二家店呢。"\n\n第二家店开在 Camden。你帮她设计了菜单，做了 logo，谈下了房租。开业那天 Mei 姐让你站在她旁边剪彩。\n\n她说："我儿子不学这行，他们要做 software engineer。" 然后她把一份合同推到你面前。"30% 干股。你管伦敦扩张。我管福建货源。"\n\n你看着她。她说："傻孩子哭什么。"\n\n你说："姨..."\n\n她说："叫姨我就给你 35%。"\n\n5 年后 Lucky Star 在伦敦有 7 家店。Mei 姐成了你婚礼上的证婚人。她在台上说："这孩子第一次走进我店里的时候，瘦得跟根筷子似的..." 你笑着哭了。',
    },
  },
  {
    id: 'whitmore_double',
    condition: ({ flags }) => flags.high_table && flags.thesis_polished,
    allowLink2UrEcho: true,
    ending: {
      title: '《剑桥评论》的作者', subtitle: 'A Voice in Print',
      text: '8 月。你的论文不仅拿了 Distinction，还被 *Cambridge Review of Cultural Studies* 接收发表。\n\n这是你专业领域里全英最权威的期刊之一。审稿人留言："Original thinking. A fresh voice. Recommended for publication with minor revisions."\n\nWhitmore 把样刊递给你的时候手有点抖。"读读看吧。"\n\n你翻到你的文章。作者署名后面的"University of London" 让你愣了 5 秒。\n\n他说："你不再是那个不敢举手的孩子了。" 你看着他，第一次发现他眼睛是浅蓝色的。\n\n临走时他说："我退休了。九月。" 你说："Sir—"\n\n他打断你："Don\'t \'sir\' me anymore. Call me James."\n\n你叫不出口。你只是用力地握了握他的手。',
    },
  },
  {
    id: 'wangkai_double',
    condition: ({ flags }) => flags.xmas_grind && flags.wangkai_apprentice,
    ending: {
      title: '"哥们 仗义"', subtitle: 'Brothers in Bubble Tea',
      text: '王凯本来想自己回国搞奶茶。后来他改主意了。"哥们 你跟我一起。"\n\n你们俩 8 月毕业，9 月就开了 Lucky Tea 第一家。10 月开第二家。半年开 8 家。\n\n你管运营，他管供应链。你说英文，他说潮州话。你写 BP，他撒酒疯。你们吵过架，差点散伙过两次。但每次都和好。\n\n3 年后 Lucky Tea 在英国 32 家店，估值 £8M。你们俩上了《福布斯 30 under 30》。\n\n采访那天记者问你们："是什么让你们成功？" 王凯叼着烟说："命好。"\n\n记者笑了，转向你。你想了想，说："是那个 2024 年的圣诞，他扔给我 £2500 现金那个晚上。我那时候才 22 岁，那是我第一次觉得，自己也算个人物了。"\n\n王凯听了，把烟摁灭了。然后说："滚。" 但你看到他眼睛红了。',
    },
  },

  // ============================================================
  // Tier 2 — 单 NPC 延伸结局
  // ============================================================
  {
    id: 'sarah_cotswolds',
    condition: ({ flags }) => flags.cotswolds_xmas,
    allowLink2UrEcho: true,
    ending: {
      title: 'Cotswolds 的窗', subtitle: 'A Window in the Hills',
      text: '毕业后你搬去了 Cotswolds 附近的一个小镇，因为伦敦房租太贵。\n\nSarah 家离你 20 分钟车程。每个周日你去他们家蹭饭。她妈坚持每周给你打包冷冻 stuffing 让你带回去。\n\n你写远程文案为生，工资不高，但够生活。Sarah 在牛津读 PhD，每隔一周回家一次，你们一起去镇上的 pub。\n\n圣诞那天，Sarah 妈做完 turkey 之后说："我想问问你的妈妈，今年要不要也飞过来过节？我想认识她。"\n\n你愣了。然后哭了。\n\n两个月后，你妈来了 Cotswolds。她不会英语，Sarah 妈不会中文。她们两个站在厨房里，比着手势教对方做饺子和 Yorkshire pudding。你和 Sarah 站在门口看着，没说话。\n\n这就是家。',
    },
  },
  {
    id: 'aditi_india',
    condition: ({ flags }) => flags.visited_india,
    allowLink2UrEcho: true,
    ending: {
      title: '印度的春天', subtitle: 'Spring in Mumbai',
      text: '毕业后你做了一个决定——去孟买待半年。\n\nAditi 给你介绍了她大学的导师，你做客座研究员，免费住她家。她爸爸虽然瘦了，但精神好多了。每天早上他给你做 chai，问你"How are you, beta?" beta 是孩子的意思。\n\n半年里你学会了说一点 Hindi，你学会了用手吃咖喱，你学会了在 35 度的阳台上读论文。\n\nAditi 妈妈给你一个金色的护身符，说"This is for safe travels." 你戴着它回了伦敦，然后又回了中国。它现在挂在你的钥匙圈上。\n\n你从来不是一个会去印度的人。但你成了那个去过印度的人。\n\n所以你也可以成为别的什么人。这就是 Aditi 教会你的事。',
    },
  },
  {
    id: 'mei_family',
    condition: ({ flags }) => flags.mei_family,
    ending: {
      title: '叫一声"姨"', subtitle: 'Calling Her "Auntie"',
      text: '毕业后你在 Mei 姐家住了三个月。她小儿子的房间——他去寄宿学校了。\n\n你早上 7 点起来帮 Mei 姐去 New Covent Garden 进货。下午在店里端盘子。晚上回家陪她和她老公吃饭。她老公话很少，但每次你回家都会问一句"今天累不累"。\n\n你慢慢明白 Mei 姐为什么对你这么好——你长得有点像她妹妹的孩子，30 年前没能来英国和她团聚的那个表妹/表弟。\n\n你没有再叫她"Mei 姐"。你叫她"姨"。\n\n姨。\n\n这一个字，是你来英国之后，最难学会、也最珍贵的一个字。',
    },
  },
  {
    id: 'whitmore_high_table',
    condition: ({ flags }) => flags.high_table,
    allowLink2UrEcho: true,
    ending: {
      title: '坐到桌子那头', subtitle: 'A Seat at the Table',
      text: '毕业三年后你回到这所大学——做了 Whitmore 的同事。年轻 lecturer，三年合同。\n\n第一次 College High Table dinner 你坐在他对面。Lord Kerridge 还在，认出你了："Ah, you\'re the one with the joke about Hegel!" 全桌笑。\n\n席间你听他们辩论了 3 小时。这一次你不再是听众。你说了 5 次话，每次都有人接你的话。Whitmore 在旁边假装没看你，但你知道他在偷偷笑。\n\n席散时你们走出 quad。雪刚下。他说："Welcome to the table, my friend."\n\n你说："Thank you, James."\n\n他终于笑出声。',
    },
  },
  {
    id: 'wangkai_grind_or_apprentice',
    condition: ({ flags }) => flags.xmas_grind || flags.wangkai_apprentice,
    ending: {
      title: '£2500 的那个晚上', subtitle: 'The £2500 Night',
      text: '毕业后你没回国，也没找正经工作。\n\n你跟王凯合开了一家小奶茶店。第一年艰难得要命——你们俩睡店里，吃外卖剩饭，瘦得像两根麻杆。但第二年开了第二家。第三年第五家。\n\n爸妈一开始不理解，后来看到你寄回家的钱，慢慢闭嘴了。\n\n你和王凯之间有一个秘密——那个 2024 年圣诞，他扔给你 £2500 现金的那个晚上，你们俩抱头痛哭了。两个 24 岁的大男人/男生女生在凌晨 4 点的奶茶店里，黑眼圈下到颧骨，傻笑着哭。\n\n那一晚你们决定，这辈子要做出点什么。\n\n你做出来了。',
    },
  },
  {
    id: 'eurotrip_sarah',
    condition: ({ flags }) => flags.eurotrip_sarah,
    allowLink2UrEcho: true,
    ending: {
      title: '5 个国家的春天', subtitle: 'Spring in Five Countries',
      text: '那 21 天的欧洲穷游成了你和 Sarah 之间的一个永久的私人语言。\n\n5 年后她结婚了，新郎不是你。你们没在一起过，从来不会，你们都知道。\n\n但每年 4 月，无论你们身在何处，她都会发来一张照片：可能是巴黎的某个咖啡馆，可能是雅典 Acropolis 的夕阳，可能是米兰大教堂的鸽子。\n\n配文永远只有四个字母："I miss."\n\n你也永远回同样的字："Me too."\n\n这是有些朋友才有的特权。这是有些春天才会留下的东西。',
    },
  },
  {
    id: 'easter_aditi_pact',
    condition: ({ flags }) => flags.easter_aditi_pact,
    allowLink2UrEcho: true,
    ending: {
      title: '把彼此变好的人', subtitle: 'Made Each Other Better',
      text: '毕业后 Aditi 回了 Bangalore，你回了北京/上海。\n\n但你们的 7am pact 没停。每天早上 7 点（北京时间）/ 4:30 (Bangalore)，你们俩同时开 zoom，互相督促健身、写作、读书。这个习惯持续了 6 年。\n\n6 年里你们都升职了，都瘦了，都读了 100 多本书。你们见证了对方的恋爱、分手、再恋爱。\n\nAditi 后来说，她爸爸去世前最后几句话之一是："Tell your friend I said thank you." 你哭了一个下午。\n\n世界上最好的友谊不是热烈的，是长久的。是那种 6 年风雨无阻的、4:30 的 zoom 通话。\n\n是那种，"You have me. Always."',
    },
  },

  // ============================================================
  // 林南 · 恋爱线结局（player must complete linnan ch5）
  // ============================================================
  {
    id: 'linnan_stayed',
    condition: ({ flags }) => !!flags.linnan_stay_together,
    allowLink2UrEcho: true,
    ending: {
      title: '我们都留了下来', subtitle: 'Together in London',
      text: '毕业 3 年后。你和林可儿 / 林楠还在伦敦。\n\n你们租了 Hackney 一套二居，月租 £1,800。两人合分。第一年你们俩都在小公司——你做 product，ta 做 strategy consulting。第二年都换到了带 sponsor 的中型公司。第三年你们攒够钱去 Skye 度了一周假。\n\n爸妈那边 ta 妈终于知道了你存在——还托人给 ta 介绍杭州相亲的那次，ta 终于摊牌。她妈哭了 3 天，不接电话。第四天突然打来："那个孩子是 ABC 还是大陆的？" "大陆的。" "..在伦敦读什么？" 你听见 ta 妈在电话那头收声音的喘气。3 个月后，你们一起回杭州看了她妈一面。\n\n她做了一桌菜——多放了一双筷子。\n\n你们没结婚，但 5 年内不会分开。这就够了。',
    },
  },
  {
    id: 'linnan_ldr',
    condition: ({ flags }) => !!flags.linnan_long_distance,
    ending: {
      title: '一年后她 / 他真的来了', subtitle: 'A Year, Then Forever',
      text: '你回国后第 11 个月。你已经在国企做了 8 个月。\n\n林可儿 / 林楠突然给你发消息："我下周回北京 / 上海。我裸辞了。"\n\n你愣了 30 秒。然后回："为什么？"\n\nta："我在伦敦做 consulting 加了 1 年班。我不知道我活成什么样子了。我想回家。我想跟你试一试。"\n\n你回："我接你机。"\n\n你们没办法保证未来——但你们知道这一刻是真的。',
    },
  },
  {
    id: 'linnan_broke',
    condition: ({ flags }) => !!flags.linnan_breakup,
    ending: {
      title: '没有谁的错', subtitle: "Neither Wrong",
      text: '毕业后 4 年。你在杭州。你听说林可儿 / 林楠还在伦敦——拿了 ILR，做着她 / 他喜欢的工作，跟一个 American 在一起。\n\n你不嫉妒，也不后悔。\n\n你只是偶尔在 LinkedIn 上看到 ta 的更新——5 年工作纪念、升职、买房——心里有一种"那条路我没走"的轻微空缺。\n\n你想：感情不是数学，没有正确答案。我们都对自己诚实过。这是最好的版本了。',
    },
  },

  // ============================================================
  // Tier 3 — 原稀有结局
  // ============================================================
  {
    id: 'oxford',
    condition: ({ flags, stats }) => flags.oxford_ref && stats.academic >= 70,
    allowLink2UrEcho: true,
    ending: {
      title: '牛津的录取信', subtitle: 'The Oxford Letter',
      text: '4 月。一封 DPhil offer 躺在你的邮箱里。Christ Church 给的全奖。\n\n你想起一年前坐在 Heathrow 的样子——什么都不懂，什么都怕。\n\n你打开 Whitmore 的邮件回他："Thank you. I don\'t know how to thank you." 他回了三个字："Earn it."\n\n你在伦敦的 flat 里坐了很久。你来留学的所有理由——证明给爸妈看，证明给前男友/女友看，证明给那个自己看——都已经不重要了。\n\n你只是想知道更多。这就够了。',
    },
  },
  {
    id: 'returned_with_wk',
    condition: ({ flags }) => flags.returned_with_wk,
    ending: {
      title: '回去创业', subtitle: 'The Bet',
      text: '你跟王凯回了国。第一年开了 3 家奶茶店。第二年扩到 12 家。第三年——你不知道。\n\n但你父母再也不催你"找份稳定的工作"了。你妈在朋友圈发你的店开业的照片，配文"我儿子/女儿在创业"。\n\n伦敦的两年好像一场梦。你偶尔会想念 Sarah，想念 Aditi，想念图书馆 4 楼。\n\n但你不后悔。这次是你自己选的路。',
    },
  },
  {
    id: 'aditi_sarah',
    condition: ({ storyProgress }) => (storyProgress.aditi || 0) >= 5 && (storyProgress.sarah || 0) >= 4,
    allowLink2UrEcho: true,
    ending: {
      title: '我的人在异乡', subtitle: 'My People',
      text: '毕业典礼那天 Sarah 哭了，你也哭了。Aditi 视频连线进来，三个人挤在一个小小的屏幕里傻笑。\n\n你拍了一张照片发到家族群。妈妈问"这两个女孩/男孩是谁？"\n\n你回："这是我朋友。"\n\n这五个字在你嘴里转了一年，今天才终于说得出口。',
    },
  },
  {
    id: 'mei_belonging',
    condition: ({ storyProgress, stats }) => (storyProgress.mei || 0) >= 3 && stats.belonging >= 50,
    ending: {
      title: '留在 Mei 姐身边', subtitle: 'Family',
      text: '毕业后你没回国。你在 Mei 姐的中餐馆做了一年。她让你管点单系统，你帮她改了菜单，加了一行小字"Welcome home."\n\n你妈一开始不理解："读了这么多书去端盘子？"\n\n但你知道你在做什么。你在还债——还给那个第一次走进 Mei\'s 的、孤单到差点崩溃的自己。你想让别的孩子也有这样一个地方可去。',
    },
  },

  // ============================================================
  // Tier 4 — 通用兜底
  // ============================================================
  {
    id: 'becoming',
    condition: ({ stats }) => stats.belonging >= 60 && stats.academic >= 55,
    allowLink2UrEcho: true,
    ending: {
      title: '找到自己', subtitle: 'Becoming',
      text: '毕业典礼那天下着小雨。你穿着学袍，在 quad 里和朋友们拍照——他们来自六个不同的国家。\n\n你没有变成一个"英国人"，也没有变回出国前的那个你。你成了一个新的人。\n\n你不知道接下来去哪里。但第一次，你不害怕。',
    },
  },
  {
    id: 'graduated_numb',
    condition: ({ stats }) => stats.belonging < 25,
    ending: {
      title: '麻木地毕业', subtitle: 'Graduated',
      text: '你毕业了。GPA 还不错。简历可以加一行 "MSc, [University]"。\n\n但你想不起来上一次真正笑出声是什么时候。你的英国手机号马上要停了，朋友圈三个月没更新。\n\n你以为留学会改变你。回过头看，它只是把你压扁了一点，又让你站起来继续走。',
    },
  },
  {
    id: 'survivor',
    condition: ({ stats }) => stats.wallet >= 1500 && stats.belonging < 45,
    ending: {
      title: '打工人', subtitle: 'Survivor',
      text: '你毕业的时候存款比来的时候还多。你在中餐馆、奶茶店、代购、家教之间来回切换。\n\n你的英语进步很慢，因为你说得最多的是"哥要不要加波霸"。\n\n但你不后悔。你证明了自己可以靠自己活下来。',
    },
  },
  {
    id: 'staying',
    condition: () => true,  // catch-all
    ending: {
      title: '留下来', subtitle: 'Staying',
      text: '你申请了毕业生工签，签证批了。你找了一份不算理想但能糊口的工作，搬到了 zone 4 一个更便宜的房子。\n\n你成了那种"已经在英国五年了"的人——朋友圈里偶尔出现，过年的时候微信群里说"今年又不回了"。\n\n你已经是一个永久的异乡人。这不是失败，也不是胜利。这只是，你的人生现在的样子。',
    },
  },
];

/**
 * Special endings triggered mid-game (visa loss, broke, crisis quit).
 * These bypass the regular table.
 */
export const SPECIAL_ENDINGS = {
  visa_curtailed: (rate) => ({
    title: '签证撤销', subtitle: 'Visa Curtailed',
    text: `Home Office 的信件比想象中简洁。"Your visa has been curtailed."\n\n累计出勤率 ${rate}%。学校已上报。\n\n28 天内离境。\n\n那些你以为不重要的早 9 课，原来真的会决定你的一切。`,
  }),
  broke: () => ({
    title: '回去', subtitle: 'Going Home',
    text: '你撑不下去了。机票订在两周后。\n\n你给爸妈打电话，没敢说真话。',
  }),
};

/**
 * Build a single Link2Ur echo line for endings that opt in (allowLink2UrEcho).
 * Only fires when player was active enough to make the mention earn its place
 * (≥ 5 单 + 评分 ≥ 4.5). Uses real numbers from state — not generic copy.
 */
function buildLink2UrEcho({ link2urRating = 0, link2urCompletedCount = 0 }) {
  if (link2urCompletedCount < 5 || link2urRating < 4.5) return '';
  return (
    '\n\n——\n\n_(Link2Ur · 多年以后)_\n'
    + 'app 你已经很少打开。但你的 profile 还挂在那里：'
    + `${link2urCompletedCount} 单 · ⭐ ${link2urRating.toFixed(1)}。\n\n`
    + '偶尔有刚下飞机的新生 DM 你想问问怎么"扛过那一年"——\n'
    + '你回得很慢，但都回了。'
  );
}

/**
 * Walk endings table top-down, return first whose condition matches.
 * Always returns a value (the catch-all is "staying").
 *
 * If the matched ending has `allowLink2UrEcho: true`, append a Link2Ur echo
 * paragraph using state.link2urRating / state.link2urCompletedCount.
 */
export function resolveEnding(state) {
  for (const e of ENDINGS) {
    if (e.condition(state)) {
      const echo = e.allowLink2UrEcho ? buildLink2UrEcho(state) : '';
      return { id: e.id, ...e.ending, text: e.ending.text + echo };
    }
  }
  const last = ENDINGS[ENDINGS.length - 1];
  return { id: last.id, ...last.ending };
}
