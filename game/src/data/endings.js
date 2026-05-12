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
  // 隐藏专属结局 — Link2Ur 合伙人 #03
  // 触发条件：Priya 的 ops_partner storyline 走完 + 接单 ≥ 30。
  // ============================================================
  {
    id: 'link2ur_partner',
    // `l2u_partner_accepted` 本身就意味着玩家走完了 50 单 chat → ambassador → partner storyline。
    // 30 这个旧阈值跟 50 阈值的 chat 触发条件矛盾（永远被 50 覆盖），删掉。
    condition: ({ flags, link2urRating = 0 }) =>
      !!flags?.l2u_partner_accepted && link2urRating >= 4.8,
    ending: {
      title: '合伙人 · #03', subtitle: 'Co-founder, Link2Ur',
      text:
        '毕业两年后。Old Street 一间小办公室——Link2Ur 创始团队 7 个人。你是 #03 合伙人。\n\n'
        + 'Priya 当年面试你的原话不像 HR："你那一年我们看过后台数据。30+ 单 4.9 评分。'
        + '更稀奇的是——你接的 18% 是亏本单（路费比报酬高）。系统标过你 7 次\'经济不理性\'。'
        + '我们想找的人就是这种——你不是 calculated optimizer，你是把别人接住的人。"\n\n'
        + '你没解释——但你心里知道。\n\n'
        + '那不是不理性。那是当时的你 22 岁，刚从 Heathrow 走出来 8 个月，'
        + '被一个 Sarah / 一个 CSSA 学姐 / 一个 Mei 姐接住过——你只是想替系统记住"被接住"是什么感觉。\n\n'
        + '现在你跟 Priya 在 Old Street 那个不到 80 平米的 office 里——你拿 4% equity + £40k 工资 + 决策权。'
        + '你 own "新生互助" 模块整条产品线。你写过的一个 spec 标题：'
        + '《如何让一个刚下飞机的孩子在 8 个月内觉得 "我没有掉下去"》。\n\n'
        + 'Priya 看完 spec 那天，她在白板上写：'
        + '"我们没法保证每个新生都有一个 Mei 姐。但我们至少可以保证有一个 app。"\n\n'
        + '她把白板拍了照，发给你 + 其它 5 个合伙人。配一句话："这就是 Link2Ur 的 mission statement。"\n\n'
        + '你下班走出 Old Street 站。伦敦的 5 月，天还亮着。\n\n'
        + '你想起一年前那个在 Bloomsbury Surgery 排队取药的下午——\n\n'
        + '那时候你不知道，原来你后来会跟当年帮你做这个 app 的人一起 own 这个 app。',
    },
    allowLink2UrEcho: false,
  },

  // ============================================================
  // 隐藏结局 — 通过 Link2Ur 试错发现 passion → 入职正规公司
  // 条件：完成 ≥ 10 种不同 task type + l2u_passion arc 走完
  // ============================================================
  {
    id: 'link2ur_passion_found',
    condition: ({ flags, link2urCompleted = [] }) => {
      if (!flags?.l2u_passion_chosen) return false;
      // t.type 是任务类别 (shopping/digital/cooking/...)，~12 个；要求接触过 ≥ 8 类才走"试错发现"叙事。
      // 兼容老存档：type 缺失时回退到 templateId，至少不会全部归并成 1。
      const uniqueTypes = new Set(link2urCompleted.map(t => t.type || t.templateId).filter(Boolean));
      return uniqueTypes.size >= 8;
    },
    allowLink2UrEcho: false,
    ending: {
      title: '我喜欢的事', subtitle: 'I Found What I Like',
      text:
        '毕业后第 14 个月。你坐在 Soho 一家 design studio 的角落工位——你 own 一条 packaging design 产品线。\n\n'
        + '你怎么走到这里的——这套故事你跟 5 个人讲过：\n\n'
        + '本来你想做 finance（家里说的）。但你在 Link2Ur 上接过 32 单 12 种不同的活。'
        + '其中 8 单是 PPT 美化 / logo 设计 / 婚礼跟拍 / 餐厅菜单排版——你发现你**接这些活的时候不累**。'
        + '其它 24 单（代购 / 跑腿 / 翻译）做完你只想躺。\n\n'
        + '第 28 单完成那天你给妈打电话："妈我可能不进咨询公司了 我想试 design 方向。"\n'
        + '她沉默 8 秒。然后说："你自己想清楚的话 妈支持。但是要交得起房租。"\n\n'
        + '你去面试这家 studio 时 portfolio 里有 11 个 Link2Ur 作品 + 5 个学校项目。creative director 看完说：\n'
        + '"我没见过 portfolio 里有这么多 paid work 的 graduate fresh out。"\n\n'
        + '你 entry-level 工资 £29k——比咨询 BCG £55k 少一半。'
        + '但你早上 8 点醒来不需要 caffeine 就能坐到桌前。\n\n'
        + '你后来告诉妈："我现在的工资是 BCG 一半 但是我能做 30 年。"\n\n'
        + '——这句话她在妈妈群里转发过。',
    },
  },

  // ============================================================
  // 隐藏结局 — 达人 → 自己创业（Link2Ur Ambassador 路径）
  // ============================================================
  {
    id: 'link2ur_daren_creator',
    condition: ({ flags, link2urRating = 0, link2urCompletedCount = 0 }) =>
      !!flags?.l2u_daren_business_launched && link2urRating >= 4.9 && link2urCompletedCount >= 30,
    allowLink2UrEcho: false,
    ending: {
      title: '我自己的店', subtitle: 'Founder',
      text:
        '毕业后第 18 个月。Soho 一家小工作室——你的 client list 12 个固定客户 + 月稳定 £5,200。\n\n'
        + 'Link2Ur 平台后台给你打了红色 "TOP 0.3% Ambassador" 标。每个月有 60+ 新 client request 你 inbox——'
        + '你只接 8 个。剩下的转给你 onboarding 进来的 4 个 Linker 学妹（每单你抽 15%）。\n\n'
        + '你现在不接代购了。也不接 brp 陪同了。你专门做 startup brand identity + PPT。\n'
        + '40-60 小时 / 周 / 月入 £5k+。你雇了一个 part-time 学弟做账。\n\n'
        + '上个月你给 Companies House 注册了 limited company：「[你的名字] Studio Ltd」。'
        + 'PSW 那 2 年攒的客户 + Link2Ur 30 单 4.9 评分 + 妈给你的 £8k 启动资金——\n'
        + '你成了那种"在 Link2Ur 起家的"案例。Priya 在某次 Ambassador summit 上提了你一句。\n\n'
        + '你毕业前那 30 单接得不算计 ROI——'
        + '你接过一单 Hyde Park 遛狗 £15 / 1 小时，比你 Mei 姐打工还低；'
        + '但你也接过一单 Bicester 代购 4 个 Burberry £180 / 一天。\n'
        + '混搭着接了一年 12 种活，你发现自己**比别人会的事多 5 倍**——'
        + '这就是创业 founder 的 baseline。\n\n'
        + '你给妈视频："妈 我开公司了 你跟爸说一声。"\n'
        + '她："好。你爸明天给亲戚群发。"',
    },
  },

  // ============================================================
  // 隐藏结局 — Freelance 自由职业者（自走全部 5 章 + 选 freelance_career）
  // ============================================================
  {
    id: 'freelance_path',
    condition: ({ flags }) => !!flags.freelance_career,
    allowLink2UrEcho: true,
    ending: {
      title: '自由职业的伦敦', subtitle: 'Self-Employed in London',
      text:
        '毕业后你没投简历。LinkedIn 改成 "Independent Designer · London"，Sole Trader 注册号填进 invoice 模板。\n\n'
        + '第一年月均 £4,500。第二年涨到 £6,200。第三年你雇了一个 part-time 助理（也是 CSSA 学妹）。\n\n'
        + 'Graduate Visa 到期前 6 个月你开始准备 self-sponsored skilled worker route。\n\n'
        + '5 年后你拿到 ILR。1 月递材料、3 月 BRP 寄到。晚饭妈妈视频里说"那以后你不用每年回去续签了？"你说是。她沉默 5 秒："那妈来住一个月也不用申请 visa 了。"\n\n'
        + '伦敦 5 月。你坐在自己 Hackney studio 窗台上喝一杯 oat flat white。\n\n'
        + '你想起那个 Pret 长椅上算 "£28/小时" 的下午——22 岁，账户里 £85。\n\n'
        + '窗外是英国最难得的晴天。',
    },
  },

  // ============================================================
  // Tier 1 — 双 flag 组合（最稀有）
  // ============================================================

  // Link2Ur 创业线 Tier 1 双 flag — 优先于其他 Tier 1 结局
  {
    id: 'y_double',
    tier: 1,
    condition: ({ flags, link2urTeamMembers = [] }) =>
      !!flags?.l2u_y_invited &&
      !!flags?.link2urPath_team &&
      !!flags?.l2u_y_merger_accepted &&
      link2urTeamMembers.length >= 4,
    ending: {
      title: 'LinkU Bespoke + AI 创始合伙人',
      subtitle: 'Founders of the New Hybrid',
      text: `W52 毕业典礼那天 Y 姐发了一条朋友圈:
"我五年前 UCL 毕业那年 没人告诉我可以这样活。但我告诉了 ta。
LinkU Bespoke 多了一个 founder。
而且 ta 带来的是我没有的:AI 让我们一个客户能赚两次。"

三年后,你们拿到 €5M A 轮。
媒体专访标题《The Hybrid That Took Over Bespoke Travel》:
"They sold a £600 day trip and a £2000 AI content pack to the same client.
That's not bundling. That's understanding what wealthy clients now expect."

Lily 的婚礼上她说: "我老公是我自己找的,
但我的伴娘是 Link2Ur 推荐的。我们结婚照的 AI 后期 也是 ta 的团队做的。"

W47 那个下午之后,你妈再没问过你"王阿姨女儿的选调"。
那天 BBC 那篇采访火了之后,她转发了三遍朋友圈。配文:
"我女儿/儿子 比我懂这个时代。"

你在 Sketch 的 pink room 跟 Y 姐喝今年的下午茶。
她说:"五年前我在这里坐着想 someday I want someone to share this with.
Now you're here. Different rooms next year — we're moving to Shoreditch."
你想: AI 替不了我们这种关系。`,
    },
  },

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
    // mei_manager 来自 holidays.js (Easter 4 周代班), mei_manager_path 来自 meiWork.js (W24+ promotion)
    condition: ({ flags }) => flags.mei_family && (flags.mei_manager || flags.mei_manager_path),
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

  // Link2Ur 创业线 Tier 2 单 flag 结局
  {
    id: 'link2ur_team_founded',
    tier: 2,
    condition: ({ flags, link2urTeamMembers = [] }) =>
      !!flags?.link2urPath_team &&
      !!flags?.l2u_y_merger_declined_independent &&
      link2urTeamMembers.length >= 2,
    ending: {
      title: '我自己的 AI Studio',
      subtitle: 'My Own Studio',
      text: `你拒了 Y 姐的合并。

她在 Sketch 把那张 napkin 收起来:"OK. 你年轻 你应该试试自己。
五年后如果你想合并 我还在。If we're both still here. And if AI hasn't replaced both of us by then. (笑)"

W52 你的团队 6 人 · 年流水 £180k · 评分 4.92 · 跨境品牌客户 retention 71%。

你没有 Y 姐的 grandfather money,也没有她 8 年的客户网络。
但你的团队全是你亲手挑的人 —— 小雨拿着 PhD 申请书来找你写推荐信,
Aman 写了一个开源的小红书投放优化脚本,GitHub 上拿了 1.2k stars。
你的客户都说这是"伦敦最懂双语的 AI 广告公司"。

Sarah 第一次看你给她男友 startup 做的 demo 视频。她说:
"This is the most 'you' thing you've ever made.
And I had no idea AI could do this."

Y 姐 W50 在 Sketch 二访时跟你说:"你能跟我打 说明我老了。"
你笑了 但你知道她其实在夸你。
Paul 的 BBC 第二季也找你了 — 你成为了"AI 时代留学生工作者"的代表。`,
    },
  },

  {
    id: 'link2ur_solo_apex',
    tier: 2,
    condition: ({ flags, link2urRating = 0, link2urCompletedCount = 0 }) =>
      !!flags?.link2urPath_solo &&
      !!flags?.l2u_solo_niche_chosen &&
      link2urRating >= 4.95 &&
      link2urCompletedCount >= 40,
    ending: {
      title: '伦敦最难约的 AI Pro',
      subtitle: 'The One Brand Calls First',
      text: `你拒了 Y 姐的邀请。

那一年你接了 31 个品牌客户,完单 67。Omar 家族 startup 出海全套素材、
蓝瓶茶饮的 UK launch campaign、Paul 那本 AI 时代书的封面 AI insight art ——
你做的不是"内容生成",是"内容策略"。 你拒掉了 50+ 个想约你的客户,
因为你说"我只接懂双语品牌战略的活","我一周只接 3 个 brief","客户给我 deck 我就不接"。

W50 Y 姐在 Sketch 主动 DM 你:
"我招过你 你没来。现在你单价比我团队任何 senior 都高。Pret 喝杯咖啡?
就这一次 我想问你一个问题。"

Pret Tottenham Court Road。她: "你怎么活下来的?一个人? AI 这两年那么卷。"
你: "我也不知道。但我每次出 brief 都是从客户那边的真问题出发,
不是从 AI 模型能做什么出发。这可能是 AI 替不掉的最后一公里。"
她笑了。结账的时候她说: "Send me your portfolio sometime. I might want to refer clients to you."

回国的飞机上 妈跟你视频说: "你王阿姨女儿那个选调还行 但她妈说从来没像你这么懂自己在干什么。"

你打开 Link2Ur,inbox 里 24 个未读。最早的那条预约写 8 个月后 — 一个中资 luxury 品牌。
你回:"sorry 我满了 推荐你试 Y 姐的团队"。然后关机。今晚要去 Mei's 吃最后一顿饭。`,
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
  {
    // friend-zone 玩家之前没有专属 ending —— linnan_4-5 章节被 linnan_dating 锁，导致
    // 这条路径的玩家全部 fall through 到主结局。补一个温情的 friend ending。
    id: 'linnan_friends_for_life',
    condition: ({ flags }) => !!flags.linnan_friend_zoned,
    ending: {
      title: '一段没发生的爱情', subtitle: 'The One That Stayed Friends',
      text: '毕业后 2 年。你和林可儿 / 林楠还偶尔互发消息——但已经不像那年 Nando\'s 第一次坐对面那样了。\n\nta 找到了一个真正合适的 partner——你也是。你们去 ta 婚礼那天你坐在 row 3。司仪问 "anyone object"——你心里有 0.5 秒的空白。然后笑出来。\n\n散场 ta 走过来抱了你一下："谢谢你那年没勉强。" 你说："谢谢你那年说出来。"\n\n回程 tube 上你想——南岸那一晚的"我们做朋友更好"——是你这一年说过最艰难也最诚实的一句话。\n\n友谊不是 fallback。是另一种完成。',
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
      text: '4 月。一封 DPhil offer 躺在你的邮箱里。Christ Church 给的全奖。\n\n你想起一年前坐在 Heathrow 的样子——什么都不懂，什么都怕。\n\n你打开 Whitmore 的邮件回他："Thank you. I don\'t know how to thank you." 他回了三个字："Earn it."\n\n你在伦敦的 flat 里坐了很久。你来留学的所有理由——证明给爸妈看，证明给前男友/女友看，证明给那个自己看——都已经不重要了。\n\n你只是想知道更多。这就够了。\n\n你在 DPhil 第一个学期还兼着接 Whitmore 介绍的学术 AI 校对客户',
    },
  },
  {
    id: 'returned_with_wk',
    condition: ({ flags }) => flags.returned_with_wk,
    ending: {
      title: '回去创业', subtitle: 'The Bet',
      text: '你跟王凯回了国。第一年开了 3 家奶茶店。第二年扩到 12 家。第三年——你不知道。\n\n但你父母再也不催你"找份稳定的工作"了。你妈在朋友圈发你的店开业的照片，配文"我儿子/女儿在创业"。\n\n伦敦的两年好像一场梦。你偶尔会想念 Sarah，想念 Aditi，想念图书馆 4 楼。\n\n但你不后悔。这次是你自己选的路。\n\n王凯三年后追加 "Y 姐去年来上海找我谈合作 — 中国茶饮品牌进 UK 跟我谈分销 跟她团队谈定制游 我说你应该是中间的那个人"',
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
      text: '毕业典礼那天下着小雨。你穿着学袍，在 quad 里和朋友们拍照——他们来自六个不同的国家。\n\n你没有变成一个"英国人"，也没有变回出国前的那个你。你成了一个新的人。\n\n你不知道接下来去哪里。但第一次，你不害怕。\n\n你在 Link2Ur 上服务的最后一个跨境品牌客户给你寄了一张明信片到杭州 —— 印着 ta 们 IG 上你做的那条广告的截图。',
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
      text: '你毕业的时候存款比来的时候还多。你在中餐馆、奶茶店、代购、家教之间来回切换。\n\n你的英语进步很慢，因为你说得最多的是"哥要不要加波霸"。\n\n但你不后悔。你证明了自己可以靠自己活下来。\n\nLink2Ur 给你写过一封感谢信 — 你删了 — 它代表的不是 dignity 而是另一种被 AI 算法消耗的劳动',
    },
  },
  // postGrad 路径分流（在 catch-all 之前，保证选了对应路径的玩家拿到对应叙事）
  {
    id: 'returned_civil_service',
    condition: ({ flags }) => !!flags.returned_civil_service,
    ending: {
      title: '回国选调那一年', subtitle: 'Returned',
      text: '你毕业典礼一周后就飞回去了。简历上"MSc, [University]" 那一行，在体制里既没人多看一眼，也没人少看一眼。\n\n你被分到一个三四线市的副科岗——通勤 20 分钟、午饭食堂、下午 5:30 下班。第一年你 cousin 问你"伦敦那种生活不想念吗"——你想了 3 秒，没回答。\n\n但每个周末你妈让你吃饭，邻居姨第一句话是"你这么帅 / 漂亮怎么还不结婚"，你想——某种 belonging 比任何 Cotswolds 周末更稳。\n\n你那一年终于学会把伦敦放在一个抽屉里——偶尔打开看一眼，然后关上。',
    },
  },
  {
    id: 'applied_phd',
    condition: ({ flags }) => !!flags.applied_phd && !flags.stayed_uk_grad,
    ending: {
      title: 'DPhil 的第一年', subtitle: 'PhD',
      text: '你 11 月提交 PhD 申请，2 月拿到一个 MPhil offer + scholarship（不是 DPhil，但有 funding）。\n\nWhitmore 退休前给你写了那封 reference——他后来邮件里说"That letter was the most over-qualified you\'ve ever been described."\n\nMSc 毕业后你直接进入了 PhD 的 reading list 和 supervisor meeting。3 年后你坐在 viva 那间小屋。10 年后你回头看，那个 22 岁刚下飞机的你做了一个改变后面 12 年的决定。',
    },
  },
  {
    id: 'psw_part_time_grind',
    condition: ({ flags }) => !!flags.psw_part_time_grind && !flags.stayed_uk_grad,
    ending: {
      title: 'PSW · 一个 Costa shift 接一个', subtitle: 'Grinding',
      text: '你拿了 PSW。但 sponsor 工签的 offer 一直没等到。\n\n你在 Costa 早班 5am-11am + 一家咨询公司 part-time research assistant 9 小时 / 周——加起来勉强够 Hackney studio £900/月 + bills + Tesco basic。\n\n你给妈视频时说"还在找"。她说"不行就回来"。你笑着说"再 1 年"——这一句话你说了 2 年。\n\n第 18 个月你拿到一个 mid-size firm 的 Skilled Worker offer——比目标晚了 18 个月，但是你自己拿下的。\n\n你回头看 Costa 那几百杯 latte——你没浪费它们。每一杯都是 commitment。',
    },
  },
  {
    id: 'returned_home_default',
    // 没拿 PSW 又没走选调/PhD 的玩家，默认是回国（不要假设"留下了"）
    condition: ({ flags }) =>
      !flags.stayed_uk_grad && !flags.applied_phd && !flags.psw_part_time_grind &&
      !flags.returned_civil_service && !!flags.no_psw,
    ending: {
      title: '回去吧', subtitle: 'Going Home',
      text: '你没申请 PSW。\n\n7 月最后一周你打包 4 个箱子——两箱书 + 一箱旧衣服 + 一箱伦敦不舍得扔的杂物（一张 Pret loyalty 卡、半盒 Yorkshire Tea、Whitmore 那张 reference letter 复印件）。\n\n国内的接机是你爸——他比你来英国前老了一点。从机场到家的车上他没说话太多，只问了一句"瘦了吗"。\n\n你回家睡了 14 小时。醒来下楼，妈在厨房——番茄炒蛋——那一刻你知道这一年的某种重量放下来了。\n\n伦敦没消失。它只是回到了一个抽屉里。',
    },
  },
  {
    id: 'staying',
    condition: () => true,  // catch-all — 默认假设玩家走了 PSW 留下
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
  stress_breakdown: () => ({
    title: '压垮了', subtitle: 'Burnout',
    text:
      '你在 ensuite 床上躺了 3 天。dissertation 没动。GP 给你开了 7 天 sick note，但学校 Wellbeing 说"建议 medical interruption 一年"。\n\n'
      + '你打电话给妈。她没问为什么。她只说"妈给你订机票"。\n\n'
      + '一年后你回伦敦完成剩下的事——那次的你和现在的你不一样了。你以前不知道一个人能"积"出 burnout，'
      + '以前以为努力就能撑过去。\n\n'
      + '伦敦教你的：求救不丢人。Link2Ur 也好、Sarah 也好、Mei 姐也好——他们都在那里。是你没去找。',
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
