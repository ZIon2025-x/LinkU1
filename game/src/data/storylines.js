export const STORYLINES = {
  sarah: {
    id: 'sarah', name: 'Sarah · 友情线', npc: 'sarah',
    chapters: [
      {
        id: 'sarah_1', title: '一杯 cider',
        trigger: { rel: 1, location: 'pub' },
        title_full: '第一次去 Pub',
        body: 'Sarah 看到你愣在吧台前，笑着走过来："First time? Try a cider, you\'ll love it."',
        choices: [
          { label: '"Thanks, that\'d be great!"', effect: { rel: 2, energy: -3, wallet: -6, belonging: 5 },
            feedback: '你们坐了一个小时。她讲她童年在 Cotswolds，你讲北京的胡同。她听得很认真。' },
          { label: '"Actually I was about to leave..."', effect: { rel: -1, energy: -2, belonging: -3 },
            feedback: '你逃出去了。在公交站你想，刚才其实不算什么。但你已经走了。' },
        ],
      },
      {
        id: 'sarah_2', title: '一起复习',
        trigger: { rel: 3, location: 'library' },
        title_full: '图书馆的下午',
        body: 'Sarah 主动坐到你对面："Mind if I join? Whitmore\'s reading list is killing me."',
        choices: [
          { label: '一起整理读书笔记', effect: { rel: 2, academic: 5, energy: -5 },
            feedback: '4 小时过去。你们都笑了好几次。她说"You actually understand this better than I do."' },
          { label: '"Sure" 然后各看各的', effect: { rel: 0, academic: 3, energy: -3 },
            feedback: '气氛有点尴尬。但你们都做完了笔记。' },
        ],
      },
      {
        id: 'sarah_3', title: '一个邀请',
        trigger: { rel: 6 },
        title_full: 'WhatsApp 上的一条消息',
        body: '"Hey! My family\'s having a thing this weekend at our place in Cotswolds. Would you wanna come? It\'s chill, just a roast."',
        choices: [
          { label: '"Yes!! That sounds amazing"', effect: { rel: 3, energy: 8, belonging: 15, wallet: -50, flag: 'cotswolds_visited' },
            feedback: '她家有一只老狗叫 Biscuit，她妈做了三种 stuffing。临走时她妈把你抱了一下，说 "Come back anytime, dear." 你回伦敦的火车上看着窗外，觉得英国突然变了一种颜色。' },
          { label: '"I\'d love to but I have a deadline 😭"', effect: { rel: -1, energy: -3 },
            feedback: '你说了谎。Sarah 回了一个 "no worries!"，但下一次她没有再叫你。' },
        ],
      },
      {
        id: 'sarah_4', title: '一个秘密',
        trigger: { rel: 9, flag: 'cotswolds_visited' },
        title_full: '凌晨两点的 Sarah',
        body: 'Sarah 凌晨两点给你打来电话。她哭着说，她和男朋友分手了。"You\'re the only person I can call right now."',
        choices: [
          { label: '听她说话，陪到天亮', effect: { rel: 4, energy: -15, belonging: 12 },
            feedback: '你们聊到 5 点。她最后说 "Thank you for being here." 你想起几个月前你们才刚认识。原来友谊就是这样建立的——不是在派对上，是在凌晨两点。' },
          { label: '说"明天再聊吧 我先睡了"', effect: { rel: -3, energy: 3 },
            feedback: '你睡了。第二天她回了一条 "Sorry for last night." 你回了 "It\'s ok"。但有些东西已经不一样了。' },
        ],
      },
    ],
  },
  mei: {
    id: 'mei', name: 'Mei 姐 · 温情线', npc: 'mei',
    chapters: [
      {
        id: 'mei_1', title: '第一次走进中餐馆',
        trigger: { rel: 0, location: 'mei' },
        title_full: '"傻孩子，第一次来吧"',
        body: 'Mei 姐看了你一眼："傻孩子，第一次来吧？" 你点点头。她说："麻婆豆腐配米饭，今天的，多给你一勺。"',
        choices: [
          { label: '"谢谢 Mei 姐"', effect: { rel: 2, wallet: -12, energy: 12, belonging: 8 },
            feedback: '你吃完饭起身付钱。Mei 姐挥手 "下次来啊。" 你走出门，伦敦的风没那么冷了。' },
        ],
      },
      {
        id: 'mei_2', title: '一份兼职',
        trigger: { rel: 3, location: 'mei' },
        title_full: '"要不要来帮忙？"',
        body: 'Mei 姐说："我们最近缺人，周末帮忙端盘子，£10/小时，包饭。考虑下？"',
        choices: [
          { label: '"好啊 Mei 姐！"', effect: { rel: 2, flag: 'mei_job', wallet: 0 },
            feedback: '你周末开始在中餐馆打工。Mei 姐有时候骂你"端盘子怎么这么慢"，但每次都会留一份饭给你。' },
          { label: '"我学业有点紧 谢谢 Mei 姐"', effect: { rel: 0 },
            feedback: 'Mei 姐点点头："读书要紧。"' },
        ],
      },
      {
        id: 'mei_3', title: 'Mei 姐的故事',
        trigger: { rel: 6, location: 'mei', flag: 'mei_job' },
        title_full: '打烊之后',
        body: '一个深夜，打烊后 Mei 姐让你坐下，倒了一杯热茶。"我跟你说，我刚来的时候，比你还小。1995年。" 她讲了一个长长的故事。',
        choices: [
          { label: '认真听完', effect: { rel: 4, energy: -3, belonging: 15 },
            feedback: 'Mei 姐讲完后笑了："说这些干嘛。你要好好读书。读出来了，别像我这样。" 你想说她活得很好。但你说不出口。你只是坐在那里，喝完了茶。' },
        ],
      },
    ],
  },

  wangkai: {
    id: 'wangkai', name: '王凯 · 创业线', npc: 'wangkai',
    chapters: [
      {
        id: 'wangkai_1', title: '第一次见面',
        trigger: { rel: 0, location: 'mei' },
        title_full: '"诶 学弟/学妹？"',
        body: '你在中餐馆吃饭。一个戴黑框眼镜的男人凑过来："诶，学弟/学妹？我看你像新来的。我王凯，PhD 二年级。加个微信？以后有什么问题问我。"',
        choices: [
          { label: '"好啊 谢谢学长"', effect: { rel: 2, energy: 1, belonging: 4 },
            feedback: '你加了他微信。三分钟后他给你转了一份"伦敦留学生省钱攻略"PDF，里面甚至有哪家 Sainsbury\'s 几点贴黄标。你想，原来真的有这种人。' },
          { label: '客气地拒绝', effect: { rel: -1, energy: -1 },
            feedback: '"啊 不用麻烦学长。" 王凯笑了笑："行行 回头有事再说。" 你后来听别的同学说他真的人挺好。但你已经错过了开口的机会。' },
        ],
      },
      {
        id: 'wangkai_2', title: '代购副业',
        trigger: { rel: 3 },
        title_full: 'Bicester 一日游',
        body: '王凯发消息："这周六去 Bicester Village 吗？我表姐让我代购 Burberry，需要个人帮我扛包。给你 £80。" 后面一个流泪的表情。',
        choices: [
          { label: '去（消耗一整天）', effect: { rel: 2, wallet: 80, energy: -18, belonging: 2 },
            feedback: '你们坐 coach 一个半小时到 Bicester。王凯排了 4 个店，你帮他抱了 6 个袋子。回来的车上他给你买了 Pret，"哥们 仗义。" £80 当场转账。你想，这一天换三天伙食费，行。' },
          { label: '不去', effect: { rel: -1, energy: 2 },
            feedback: '"理解理解 学习要紧。" 王凯发了一个 OK 的表情。但你知道下次他不会再叫你了。' },
        ],
      },
      {
        id: 'wangkai_3', title: '一个想法',
        trigger: { rel: 6, location: 'soho' },
        title_full: 'Soho 的奶茶店',
        body: '王凯约你在 Soho 一家奶茶店见面。他说："我想搞个事情。Soho / Chinatown 这边一杯奶茶卖 £6，国内成本 5 块钱。我有个表哥能搞货源。我俩合伙开个外卖店，怎么样？"',
        choices: [
          { label: '"听起来靠谱 算我一份"', effect: { rel: 3, flag: 'wangkai_business', energy: -5, belonging: 4 },
            feedback: '你说"我没什么钱投。" 他说"你出力就行，10% 股份。" 你们握了手。回去的路上你心跳得很快——这是你第一次觉得自己在伦敦不只是个学生。' },
          { label: '"我想想 学业要紧"', effect: { rel: -2, energy: 2 },
            feedback: '王凯笑了："理解 不勉强。" 他后来真的开起来了，三个月后你刷到他的小红书：80万粉丝。你心里有一根刺。' },
          { label: '"哥 你这是不是有点冒险"', effect: { rel: 1, energy: -3 },
            feedback: '"冒险才有回报啊。" 王凯笑笑。你们没谈成。但你们之间多了某种平等的东西——你也敢和他说真话了。' },
        ],
      },
      {
        id: 'wangkai_4', title: '第一桶金',
        trigger: { rel: 8, flag: 'wangkai_business' },
        title_full: '深夜的厨房',
        body: '凌晨两点，你们的奶茶外卖店第一周。订单 230 杯，王凯在熬奶茶，你在贴标签。手机响了——一个差评，一星，理由是"波霸太硬"。',
        choices: [
          { label: '"我去退款 顺便道歉"', effect: { rel: 3, energy: -8, belonging: 5 },
            feedback: '你打了 20 分钟电话。客户最后说"算了 你们不容易"，把评价改成了 4 星。王凯看着你："你比我适合做这个。" 这是他第一次正经地夸你。' },
          { label: '"差评而已 别管了"', effect: { rel: -1, energy: -3 },
            feedback: '王凯没说什么。但第二天他自己打了那通电话。你看着他的背影，突然意识到，做生意不只是赚钱，是无数次咽下委屈。' },
        ],
      },
      {
        id: 'wangkai_5', title: '一个选择',
        trigger: { rel: 11, flag: 'wangkai_business' },
        title_full: '回国还是留下',
        body: '毕业季快到了。王凯说："哥 跟我回国吧。我家那边给我们准备好了铺面，做奶茶店连锁。三年内能赚到第一个 100 万。但你得放弃 PSW 工签。" 他认真地看着你。',
        choices: [
          { label: '"我跟你回去"', effect: { rel: 4, energy: 5, belonging: 8, flag: 'returned_with_wk' },
            feedback: '你做了一个家里人都不理解的决定。但你觉得，这是你来留学之后第一次完全是为自己做的选择。三年后到底怎么样，没人知道。但你不再是那个被推着走的人了。' },
          { label: '"我想留下来 试试"', effect: { rel: 1, energy: -3, belonging: 3 },
            feedback: '王凯点头："理解。哥们记着你。" 他们走了。你独自留在伦敦。你们的友谊不会变，但你们的人生从这一刻开始走向不同的方向。' },
        ],
      },
    ],
  },

  aditi: {
    id: 'aditi', name: 'Aditi · 互助线', npc: 'aditi',
    chapters: [
      {
        id: 'aditi_1', title: '图书馆四楼',
        trigger: { rel: 0, location: 'library' },
        title_full: '凌晨一点的笔记本',
        body: '凌晨 1 点。整层只有你和她。她抬头看了你一眼，露出疲惫但友善的微笑，把她那杯还没喝完的咖啡推过来一点："Want some? I think we both need it."',
        choices: [
          { label: '接过咖啡，小聲说谢谢', effect: { rel: 2, energy: 5, belonging: 6 },
            feedback: '"I\'m Aditi." "I\'m..." 你们小声地交换了名字。她回去看书，你回去看书。但你写论文的速度突然快了起来。' },
          { label: '客气地说不用', effect: { rel: 0, energy: -2 },
            feedback: '她笑了笑，说 "Suit yourself"，回去看书。你后悔了一整晚。但下次再见，你不知道怎么开口。' },
        ],
      },
      {
        id: 'aditi_2', title: '一起 essay',
        trigger: { rel: 3, location: 'library' },
        title_full: '"Can I read yours?"',
        body: 'Aditi 主动找你："I\'m stuck on the methodology section. Could you have a look at mine? I\'ll read yours too if you want."',
        choices: [
          { label: '互相批注，认真看', effect: { rel: 3, academic: 6, energy: -8, belonging: 5 },
            feedback: '你们交换了文档。她的英文比你流利，但你的论证更清晰。你们都从对方那里学到了东西。她说"You think differently. It\'s good."' },
          { label: '"我自己还没写完 抱歉"', effect: { rel: -1, energy: 1 },
            feedback: '你撒了谎。其实你写完了，但你不敢让别人看你的英文。她说"No worries"，转身回去工作。' },
        ],
      },
      {
        id: 'aditi_3', title: '一个秘密',
        trigger: { rel: 5 },
        title_full: '凌晨的微信消息',
        body: '凌晨 2 点。Aditi 给你发消息："are you up?" 你看到这条消息。然后是："my dad\'s in the hospital. i can\'t fly back. tuition would be gone."',
        choices: [
          { label: '马上视频电话过去', effect: { rel: 5, energy: -15, belonging: 14 },
            feedback: '你们视频到天亮。她哭了很久。你不知道说什么，就一直陪着。她最后说"Thank you. Really. I don\'t have anyone here." 你说"You have me." 这是你第一次用英文说出这种话。' },
          { label: '回复"I\'m here. Want to talk?"', effect: { rel: 3, energy: -8, belonging: 8 },
            feedback: '你们打字聊到 4 点。她说她爸爸是稳定了，但她已经一周没睡好。你说有空一起吃饭。她回了一个哭脸加爱心。' },
          { label: '"I\'m so sorry, get some rest 💜"', effect: { rel: -1, energy: 1, belonging: -3 },
            feedback: '她回了"thanks"。两个字。你睡了。但那条消息你一直记得。' },
        ],
      },
      {
        id: 'aditi_4', title: '一起做饭',
        trigger: { rel: 8 },
        title_full: '"教我做炒饭"',
        body: 'Aditi 来你公寓："Teach me Chinese fried rice. I\'ll teach you proper chai." 她带了印度香料、酥油、豆蔻。',
        choices: [
          { label: '一起忙活一晚上', effect: { rel: 4, energy: 8, belonging: 18, wallet: -10 },
            feedback: '你们做了三道菜。她的 chai 比 Pret 的好喝十倍。你们吃完站在窗边，看着伦敦的灯。她说"This is the first time it feels like home." 你说"Same." 这一刻你不再觉得自己孤独。' },
          { label: '"今晚有点累 改天吧"', effect: { rel: -2, energy: 3 },
            feedback: '她说"OK"，挂了电话。你坐在床上看了半天天花板。' },
        ],
      },
      {
        id: 'aditi_5', title: '毕业前',
        trigger: { rel: 12 },
        title_full: 'Heathrow 的拥抱',
        body: '毕业季。Aditi 要回印度了。你送她去 Heathrow。她拿到了 Bangalore 一家科技公司的 offer。',
        choices: [
          { label: '"You\'ll come back to visit, right?"', effect: { rel: 3, energy: -3, belonging: 12 },
            feedback: '她抱了你很久。"You changed how I see this country," 她说。"I won\'t forget." 你回家路上在 tube 上哭了。但是是开心的那种。你的伦敦留学生活，因为这个人，再也不能被概括为一句"挺难的"。' },
          { label: '"Stay in touch. I mean it."', effect: { rel: 2, energy: -5, belonging: 8 },
            feedback: '"Of course." 她说。她进了安检，回头挥了挥手。你站了很久才离开。你知道你们大概率不会再见。但有些人就是这样——存在过，就改变了你。' },
        ],
      },
    ],
  },

  whitmore: {
    id: 'whitmore', name: 'Whitmore 教授 · 学术线', npc: 'whitmore',
    chapters: [
      {
        id: 'whitmore_1', title: '第一次 office hours',
        trigger: { rel: 0, location: 'uni' },
        title_full: '"Come in, do come in"',
        body: '你敲了 Prof. Whitmore 办公室的门。他抬头看你三秒，才反应过来："Ah, yes. You\'re in my Tuesday seminar. Sit, sit. What\'s on your mind?"',
        choices: [
          { label: '问关于 reading list 的问题', effect: { rel: 1, academic: 4, energy: -5 },
            feedback: '他听你说完，沉默了几秒，然后说"That\'s an interesting angle. Most students just ask for the page numbers." 这是你来英国第一次被这种人认真对待。' },
          { label: '问怎么写好 essay', effect: { rel: 1, academic: 3, energy: -3 },
            feedback: '"Write less. Think more." 他给了你一个简短的建议。然后递给你一本他写的书的复印本。"This might help."' },
          { label: '紧张到只问了 reading 的截止时间', effect: { rel: 0, energy: -8, belonging: -3 },
            feedback: '他笑了笑："It\'s on the syllabus, my dear." 你逃出来。你恨自己浪费了这个机会。' },
        ],
      },
      {
        id: 'whitmore_2', title: '一篇被退回的 essay',
        trigger: { rel: 2, location: 'uni' },
        title_full: '红笔下的批注',
        body: '他把你的 essay 还给你，封皮写了 62 分。"Adequate. But your argument lacks conviction. Come see me if you want to discuss."',
        choices: [
          { label: '认真去找他讨论', effect: { rel: 3, academic: 7, energy: -10 },
            feedback: '你们聊了一个小时。他指出了你思路里 5 个隐藏的逻辑漏洞，又指了 2 个你自己没意识到的亮点。"Now rewrite it." 你回去重写了，最后拿到 78。这次他没说"adequate"。' },
          { label: '不去，自己琢磨', effect: { rel: 0, academic: 2, energy: -5 },
            feedback: '你自己改了，下次拿了 65。距离他真正认可你，还很远。' },
          { label: '"我尽力了" 算了', effect: { rel: -2, academic: 0 },
            feedback: '你接受了 62。这一刻你也接受了"我就这样"的自己。' },
        ],
      },
      {
        id: 'whitmore_3', title: 'Tutorial 上的发言',
        trigger: { rel: 4, location: 'uni' },
        title_full: '一次主动举手',
        body: 'Tutorial 上，话题是 Foucault 和权力。你想到了一个观点。你的手悬在膝盖上方，犹豫了 30 秒。',
        choices: [
          { label: '举手发言', effect: { rel: 3, academic: 5, energy: -10, belonging: 6 },
            feedback: '你说完后教室安静了一秒。然后 Whitmore 慢慢点头："Yes. That\'s exactly the point most commentators miss." Sarah 在旁边小声说"damn"。你那一刻知道，你不是来这里凑数的。' },
          { label: '又一次没举起来', effect: { rel: -1, energy: -8, belonging: -5 },
            feedback: '另一个学生说了你想说的话。Whitmore 点头说"Good." 你看着自己的手，恨它。' },
        ],
      },
      {
        id: 'whitmore_4', title: '一次咖啡邀请',
        trigger: { rel: 7 },
        title_full: '"Coffee?"',
        body: 'Whitmore 在走廊里叫住你："Have you got time for a coffee? There\'s something I want to ask you."',
        choices: [
          { label: '"Of course, sir"', effect: { rel: 3, energy: -5, belonging: 8, flag: 'whitmore_coffee' },
            feedback: '他在 Senior Common Room 给你点了咖啡。"I\'m editing a journal issue on transcultural perspectives. Would you consider contributing a short piece?" 你以为你听错了。他重复了一遍。你说"Yes." 你不敢相信自己说了 Yes。' },
          { label: '"我有点紧张..."', effect: { rel: 0, energy: -3 },
            feedback: '他笑了笑："Another time then." 但"another time" 没有再来。' },
        ],
      },
      {
        id: 'whitmore_5', title: '一封推荐信',
        trigger: { rel: 10, flag: 'whitmore_coffee' },
        title_full: '"You should apply"',
        body: 'Whitmore 把一张纸放到你面前——牛津 DPhil 项目的招生信息。"I\'ve written a draft of your reference. Read it. Tell me if I got anything wrong."',
        choices: [
          { label: '颤抖着读完', effect: { rel: 3, academic: 12, energy: 5, belonging: 15, flag: 'oxford_ref' },
            feedback: '推荐信里他写："In thirty years of teaching, only a handful of students have approached the material with this level of original thinking." 你看到这句话时，眼泪掉到了纸上。Whitmore 假装没看见，递了一张纸巾。' },
          { label: '"教授 我配吗"', effect: { rel: 1, energy: -5, belonging: 5 },
            feedback: 'Whitmore 看着你："That\'s the wrong question. The right question is: do you want to?" 你想了想，点头。他说"Then you do."' },
        ],
      },
    ],
  },

  // ─────────────────────────────────────────────────────────────
  // 林南 · 恋爱线 (Sino-Sino, optional, fully gated by player choice)
  // ─────────────────────────────────────────────────────────────
  // 同 cohort 的中国留学生。从图书馆借笔记开始，到毕业前的长距离决定。
  // ch3 是承诺点（confession 前）。如果玩家选 friend-zone，事件链停在 rel ≤ 5
  // 不会推进到 ch4-5；选 dating，则继续推进。
  linnan: {
    id: 'linnan', name: '林可儿 / 林楠 · 同班同学', npc: 'linnan',
    chapters: [
      {
        id: 'linnan_1', title: '图书馆借的笔记',
        trigger: { rel: 0, location: 'library' },
        title_full: '"你的 Foucault 笔记好详细"',
        body: '图书馆 4 楼。你旁边坐着一个戴口罩的中国女生 / 男生——你认得脸，是 same cohort 的林可儿 / 林楠。每节 tutorial 都坐第一排但不太说话。\n\n她 / 他小声说："你那个 Foucault 笔记能借我抄一下吗？我做笔记跟不上。"',
        choices: [
          { label: '"行 我发给你电子版"', effect: { rel: 2, energy: 1, belonging: 5 },
            feedback: '你 AirDrop 给 ta 一份 12 页的 Word 文档。ta 翻了一下："你这个比 reading list 还系统..."\n\n"加个微信？以后互相 cover 笔记。" 你扫了码——头像是张 Cotswolds 山的照片。备注名"林可儿 / 林楠"。' },
          { label: '"我自己也没复习好" 推', effect: { rel: -1, energy: 1 },
            feedback: '林可儿 / 林楠点点头："好，那不打扰了。" 然后专心写字。\n\n你后悔了 5 秒。但你也没追上去。' },
        ],
      },
      {
        id: 'linnan_2', title: '一起去 Nando\'s',
        trigger: { rel: 2 },
        title_full: '"我请你吃饭 谢笔记"',
        body: '林可儿 / 林楠微信："你笔记真的救了我命。这周五 cheeky Nando\'s? 我请。"\n\nSoho 那家 Nando\'s。你们点了 half chicken + medium。聊到一半 ta 说："我学的是社会学但本科是金融——我爸觉得我跑偏了。你呢？"',
        choices: [
          { label: '认真讲自己为什么来读这个', effect: { rel: 3, energy: 3, belonging: 8 },
            feedback: '你讲了 30 分钟你大学转专业的事。林可儿 / 林楠听得很认真——ta 自己点的 lemon & herb 都凉了。\n\n临走时 ta 说："我以为只有我一个人这样。" 你说"我以为只有我一个人这样"。两个人在 Nando\'s 门口愣了一秒，然后笑了。\n\n回家路上你想：原来同一个 cohort 里，还有人和我同一种焦虑。' },
          { label: '聊得很客气 没讲深', effect: { rel: 0, energy: -1 },
            feedback: '你们聊了 essays、tutor、weather。结账时 AA。\n\n林可儿 / 林楠说"下次再约"。但你们都知道——这次"再约"是英国版客气。' },
        ],
      },
      {
        id: 'linnan_3', title: '跨年夜的告白',
        trigger: { rel: 5 },
        title_full: '"我喜欢你 你怎么想？"',
        body: '12 月 31 日。Trafalgar Square 跨年烟花。\n\n你和林可儿 / 林楠挤在 Big Ben 视野最好的一个角落。10、9、8、7...\n\n烟花起来那一瞬间——林可儿 / 林楠转过头看你 3 秒。然后说："我有点话想跟你说。我们走一段。"\n\n你们沿着泰晤士河走。ta 突然停下来："我……喜欢你。如果你只是想做朋友我也理解。但我想试一次。"',
        choices: [
          { label: '"我也喜欢你"', effect: { rel: 4, energy: 5, belonging: 18, flag: 'linnan_dating' },
            feedback: '你们站在 South Bank 的栏杆边接吻。冷得鼻子都冻了，但你们都笑了。\n\n"一年了 我一直以为你看不出来。" 林可儿 / 林楠说。你说"我看出来了。我就是不敢。"\n\n这是你来英国第一个真正的"我们"。' },
          { label: '"我们做朋友更好"', effect: { rel: 0, energy: -5, belonging: 4, flag: 'linnan_friend_zoned' },
            feedback: '林可儿 / 林楠愣了 3 秒。然后笑了一下："好。我也不勉强。但我说出来比憋着好。"\n\n那一晚后你们还是朋友。但 ta 主动找你的频率明显少了。\n\n你想：拒绝是诚实的。但诚实有时候很重。' },
          { label: '"我需要时间想想"', effect: { rel: -2, energy: -8, belonging: -3 },
            feedback: '林可儿 / 林楠点头："OK。" 然后两个人继续走完那段路，气氛很 awkward。\n\n3 周后 ta 在群里宣布有了新的 partner。你看着那条消息——你不能怪 ta，但你也不能不难受。' },
        ],
      },
      {
        id: 'linnan_4', title: '春节回国错过',
        trigger: { rel: 9, flag: 'linnan_dating' },
        title_full: '"今年我们都回去了 但没见到"',
        body: '春节假期。你回国，林可儿 / 林楠也回国——你们俩在不同城市（你北京 ta 杭州）。\n\n你们计划见一次。但 ta 妈妈安排了三天相亲：邻居女儿 / 儿子、初中同学、爸的下属。ta 妈不知道 ta 在英国有 partner。\n\nta 给你打视频："我没办法见你。这次我妈不放过我。"',
        choices: [
          { label: '"理解 我们伦敦再见"', effect: { rel: 3, energy: -3, belonging: 12 },
            feedback: '你们视频聊了 1 小时。你说"你跟你妈说一声实情吧"，ta 沉默 5 秒："等回伦敦了再说。"\n\n你回伦敦时 ta 飞机比你晚一天。你在 Heathrow 接 ta——ta 一出 Arrivals 就抱住你。"我妈相亲安排了 5 个。我都没去最后一个。"\n\n你笑了。你想："我们走过这关了。"' },
          { label: '"你跟你妈摊牌啊"', effect: { rel: -2, energy: -5, belonging: -3 },
            feedback: '林可儿 / 林楠脸色一沉："你不懂我妈。她会哭一个月。"\n\n你们吵了 30 分钟然后挂了电话。3 天没联系。\n\n你不知道这段感情还有没有可能。但你也不想道歉——你说的也没错。' },
        ],
      },
      {
        id: 'linnan_5', title: '毕业前夜 · 长距离吗',
        trigger: { rel: 12, flag: 'linnan_dating' },
        title_full: '"接下来我们怎么办？"',
        body: '毕业前一周。你和林可儿 / 林楠躺在你的 ensuite 床上——透过那扇朝着隔壁砖墙的窗户能看到一点点天。\n\nta 拿了 PSW 工签，准备留 London 找咨询岗。你的工作还没着落，可能要回国。\n\nta 说："我不催你。但我也想知道——我们接下来是 long-distance、还是一起回国、还是分开。"',
        choices: [
          { label: '"我留下来 试 2 年"', effect: { rel: 5, energy: 8, belonging: 25, flag: 'linnan_stay_together' },
            feedback: 'ta 哭了。你也哭了。\n\n"我以为你会说回国。" "我以为你想一起回去。"\n\n你们躺在那张单人床上聊到天亮——伦敦租房、Skilled Worker visa 续签时间、5 年后能不能拿 ILR。\n\n两个人在异乡决定一起留下，比在家乡决定要重得多。' },
          { label: '"我回国 你来找我？"', effect: { rel: 2, energy: -5, belonging: 8, flag: 'linnan_long_distance' },
            feedback: 'ta 说："好。给我 1 年时间在伦敦再试试。1 年后我回来找你。"\n\n你们说好。\n\n你不知道 1 年后 ta 还会不会来。但你知道——这一刻你们都尽力了。\n\n这就是异乡的恋爱：你不能要求对方为你放弃 ta 也奋斗了半生的城市。' },
          { label: '"我们应该到此为止"', effect: { rel: -3, energy: -10, belonging: -5, flag: 'linnan_breakup' },
            feedback: 'ta 看了你 10 秒。然后说："好。"\n\n你们没吵架。ta 穿衣服走了。第二天给你发了一条："谢谢你这一年。" 然后删了好友。\n\n你坐在床上看着那扇窗。这一年最复杂的告别——没怪谁，但都受伤。' },
        ],
      },
    ],
  },
};
