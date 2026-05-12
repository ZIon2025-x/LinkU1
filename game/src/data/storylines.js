import { LINK2UR_CHAPTERS } from './link2urMainline.js';

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
        trigger: { rel: 0, location: 'library', minWeek: 2 },
        title_full: '凌晨一点的笔记本',
        body: '凌晨 1 点。整层只有你和她——你认得这张脸，她周二 tutorial 坐你斜后方。她抬头露出疲惫但友善的微笑，把刚拆封的 Pret 小饼干往你这边推："Want one? I think we both need a sugar hit."',
        choices: [
          { label: '"Thanks 🙏" 接过一块', effect: { rel: 2, energy: 5, belonging: 6 },
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
        trigger: { rel: 0, location: 'uni', minWeek: 2 },
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
        // 之前要求 `flag: whitmore_coffee`（只在 ch4 option 1 set），ch4 选了
        // "我有点紧张" 的玩家即使 rel 后续涨到 10 也永远进不来 → oxford_ref
        // ending 不可达。改成 rel-only：narrative 仍连续（"推荐信"不强依赖咖啡店那场对话）。
        trigger: { rel: 10 },
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
        trigger: { rel: 0, location: 'library', minWeek: 3 },
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

  // ─────────────────────────────────────────────────────────────
  // Y 姐 · Link2Ur AI 创业线 (第 7 主线)
  // ─────────────────────────────────────────────────────────────
  yjie: {
    id: 'yjie_mainline',
    name: 'Y 姐 · Link2Ur AI 广告创业线',
    npc: 'yjie',
    chapters: LINK2UR_CHAPTERS,
  },

  // ─────────────────────────────────────────────────────────────
  // 反诈线 (scam_education) - 教玩家识别针对海外华人的常见诈骗。
  // ─────────────────────────────────────────────────────────────
  // 不绑 NPC，纯靠 minWeek + flag 推进。每章演一种真实存在的套路：
  //   ch1: 仿冒大使馆电话（"涉洗钱"威胁）
  //   ch2: 快递包裹"海关清关费"短信钓鱼
  //   ch3: Tinder/Hinge 杀猪盘（pig butchering）
  //   ch4: 老兵回头帮新生（要求至少抗住 2 次）
  scam_education: {
    id: 'scam_education', name: '反诈这一年', npc: null,
    chapters: [
      {
        id: 'scam_1', title: '"中国驻英大使馆来电"',
        trigger: { minWeek: 4 },
        title_full: '+44 020 79... 来电',
        body: '下午 3 点。陌生英国号码打来。\n\n机器人女声："本机为中国驻英大使馆领事保护中心。您名下护照涉及一起境外洗钱案，请按 1 接通办案专员。"\n\n按 1 后—— 一个普通话男声很官方："请问您是 ××× 同学吗？您的 BRP 号 ×××××× 我这边查到您 8 月 14 日有一笔可疑跨境转账。需要您在 2 小时内将名下所有资金转至我们指定的"安全账户"接受清查，否则将冻结您的护照、限制出入境。"',
        choices: [
          { label: '"假的吧" + 立刻挂断 + 群里警告', effect: { energy: 1, belonging: 6, flag: 'scam_consul_resisted' },
            feedback: '你挂断电话立刻发 CSSA 群："刚才接到大使馆电话说我洗钱要我转账 假的对吧？"\n\n5 秒不到：\n\n狗哥：假的 别转 哥们这种我接过 8 次\n@Lily：宝宝注意安全 ✨ 这种我朋友被骗过 £3000\n上岸了的姐：大使馆从来不打电话要钱。所有使馆事务必须线下预约。中国驻英使馆官网首页头条有警告。\n凯泽：靠 我说怎么前几天也接到了 我还跟那个机器人女声犟了 5 分钟\n新生小王：??? 还有这种事吗 我刚来一个月吓死我了\n\n潜水的人（出现）：注意 现在 home office 也开始有仿冒邮件了。' },
          { label: '"那我先核实一下"（继续听）', effect: { energy: -3, belonging: -1 },
            feedback: '对方语气立刻紧张："核实？这就是不配合调查！我现在就给你接公安部！" 然后转接一个所谓"上海公安"。\n\n你后知后觉发现 BRP 号他能"念出"是因为先逼你说出来的。你挂了。\n\n3 小时后你才完全冷静。心跳到现在还快。' },
          { label: '"先转 £500 试试看"', effect: { wallet: -500, energy: -10, belonging: -8, flag: 'scammed_consul' },
            feedback: '你按对方提供的账户转了 £500"诚意金"。对方立刻又说要再转 £8,000 才能"解除冻结"——你这才反应过来。\n\n那 £500 没了。你没敢告诉爸妈。后来你打电话给真的大使馆——人家说："我们从不打电话办案。这是诈骗。" 你哭了 1 小时。\n\n伦敦给你上的最贵一课：£500。' },
        ],
      },
      {
        id: 'scam_2', title: 'Royal Mail 包裹滞留短信',
        trigger: { minWeek: 9 },
        title_full: '一条来自 +44 7 ... 的短信',
        body: '你手机震动。SMS：\n\n"[Royal Mail] 您的包裹（追踪号 RM2024××××UK）因海关申报信息缺失被滞留。需在 24 小时内补缴清关费 £2.50 + 完成身份验证，否则包裹将被销毁。点击核实：royal-mail-track-uk.cn/verify"\n\n你确实在等一个国内寄来的包裹。',
        choices: [
          { label: '点开域名一看就假 + 直接删除', effect: { energy: 1, belonging: 4, flag: 'scam_courier_resisted' },
            feedback: '你看了一眼链接：`.cn/verify`。Royal Mail 是英国官方机构怎么可能用 .cn 域名。\n\n你删了短信。半小时后又收到一条同样模板，发件人换了号码。\n\n你截图发群："这是诈骗模板。Royal Mail 真的有费要补永远在 royalmail.com 信箱里。"\n\n新生小王：同学 谢谢提醒 我前天差点点了 😱\n@Lily：天 我室友昨天点了 立刻冻卡了 谢谢宝宝\n狗哥：这种破链接我闭眼都能看出来 但每次都有人中\n凯泽：补充一下：HMRC、DVLA、NHS 短信永远不附链接 全部官网信箱通知' },
          { label: '点开链接但中途警觉退出', effect: { energy: -2, belonging: -1 },
            feedback: '你点开了链接——一个仿真度很高的 Royal Mail 页面，要求你输入 BRP 号 + 信用卡 + CVV。\n\n输到信用卡那栏你停下来：Royal Mail 收 £2.50 不需要 CVV。\n\n你立刻关浏览器。第二天去银行把卡冻结重发——以防输入的 BRP 号被存了。' },
          { label: '填了信息（£2.50 看起来无害）', effect: { wallet: -200, energy: -8, belonging: -5, flag: 'scammed_courier' },
            feedback: '你填了信用卡 + CVV。对方扣了 "£2.50"。\n\n3 天后你查银行账单——同一张卡又被刷了 £200 在土耳其某个网站。你打电话给银行 dispute、cancel、补卡。流程走了 2 周。\n\n你想：£2.50 是诱饵，CVV 才是猎物。' },
        ],
      },
      {
        id: 'scam_3', title: '"Goldman Sachs Recruiter" 在 LinkedIn 找你',
        trigger: { minWeek: 16 },
        title_full: '"看了你 profile，邀请你来面试"',
        body: 'LinkedIn DM 弹出。"Olivia Chen · Senior Recruiter, Goldman Sachs Asset Management · London"。头像很职业（套装 + 公司 logo 背景）。\n\n"Hi! Saw your profile and your dissertation topic — you\'re a strong fit for our Quantitative Research summer internship 2025. We\'d like to fast-track you through. Can you complete this take-home assignment by Friday?" 附 PDF。\n\n你做了 take-home（其实题目挺合理）+ 提交 + 第二轮 video interview 也过了。3 周后她说："Final stage. We just need you to complete background check via our HR partner — £350, fully reimbursed in your first paycheck."',
        choices: [
          { label: '"正规公司不会让候选人付 background check 费" + 举报', effect: { energy: 1, belonging: 6, flag: 'scam_recruiter_resisted' },
            feedback: '你回："Goldman Sachs HR runs background checks internally. Candidates never pay. I\'ll be reporting this to LinkedIn and Action Fraud."\n\n她立刻 unmatch。你截图 + 反查 — 她头像是 Goldman 真员工 LinkedIn 盗的，名字也是真员工但不是 recruiter。整套是精心仿冒。\n\n你发 CSSA 群警告：\n\n上岸了的姐：这种已经是产业。LinkedIn 上同一头像注册 50 个号轮着用。\n@Lily：我之前也被 BCG 假 recruiter 加过 😭\n狗哥：但凡 candidate 出钱 100% 假\n凯泽：我表姐去年被这个套路骗了 £600 +\n潜水的人：之前 Reddit r/Big4 也有类似帖。' },
          { label: '"那能不能等签 contract 后再扣"（讨价）', effect: { energy: -5, belonging: -3 },
            feedback: '她："Sorry that\'s not negotiable. We can\'t process background check without payment confirmation. If you\'re not ready, we\'ll have to move to the next candidate."\n\n你看了她 message 30 分钟。差点付了。最后心一狠拒了。\n\n第二天 LinkedIn 上她已经 unmatch 你 — 印证了你的怀疑。但你也想：投行真的不可能这么快 fast-track，是我太想被认可。' },
          { label: '付了 £350', effect: { wallet: -350, energy: -10, belonging: -6, flag: 'scammed_recruiter' },
            feedback: '你付了 £350 到她说的 "HR 合作账户"。第二天她说还需要 "compliance training fee £500"。\n\n你这才反应过来。你立刻冻结银行卡 + report fraud。£350 银行 dispute 拿回来一半（£175）。\n\n净损 £175 + 一周 dispute 流程 + 那两周你 essay 没好好写——deadline 写到凌晨 4 点交。\n\n6 个月后真正的 Goldman summer internship 申请开放——你扔了简历。但这次你做了 30 分钟 background research 才回 recruiter。' },
        ],
      },
      {
        id: 'scam_4', title: '帮新生写反诈贴',
        trigger: { minWeek: 32, flag: 'scam_consul_resisted' },
        title_full: 'CSSA 群里突然有学妹差点被骗',
        body: '半夜 12 点。CSSA 群里一个新生女生发："救命 我刚收到大使馆电话说我护照有问题要我转 8000 镑 我现在该不该转"\n\n群里几个人在劝。但她说"对方说得很官方 还知道我护照号..."\n\n你看了 30 秒。',
        choices: [
          { label: '写一份长贴讲完整套路 + 自己经历', effect: { energy: -10, belonging: 18, academic: 2, flag: 'scam_educator' },
            feedback: '你坐起来打了 1500 字 + 5 张截图：\n\n· 大使馆从不打电话要钱\n· 快递诈骗的 .cn 域名鉴别\n· Hinge 上的金融男 5 周钓鱼脚本\n· Action Fraud 报案链接\n\n那个新生女生：同学 我没转 我 block 了。我刚才真的差一点。\n上岸了的姐：写得好。建议群主置顶。\n@Lily：救命 我现在浑身汗 ✨ 我妈昨天还说"在英国安全"\n狗哥：mark + 转发\n凯泽：补充：Action Fraud 报案后会给你一个 reference number 报银行 chargeback 的时候用得上\n新生小王：同学 我能存到本地吗 想发给我室友\n潜水的人：⬆️\n\n你看了一眼时间——凌晨 2 点了。3 天后群主把你的帖子置顶。' },
          { label: '简单一句"假的别转"', effect: { energy: -1, belonging: 4 },
            feedback: '你回了一句"假的 别转 直接 block"。她回"好的谢谢"。然后没下文。\n\n你后来知道她确实没转。但你也知道——你本可以多说几句。' },
        ],
      },
    ],
  },

  // ─────────────────────────────────────────────────────────────
  // 杀猪盘恋爱线 (scam_romance) - 4 章 · 让玩家以为是真恋爱
  // ─────────────────────────────────────────────────────────────
  // 设计原则：前 2 章读起来必须像正经 dating arc，没有任何 scam 信号。
  // 玩家在 ch3 才看到第一个红旗；ch4 是揭穿 / 损失 / 抗住后的 aftermath。
  // 真实模板：研究过 2024-2025 真实 pig butchering 案例 (Hinge / Coffee Meets Bagel)
  scam_romance: {
    id: 'scam_romance', name: 'Hinge 上的 Daniel', npc: null,
    forGender: 'female',
    chapters: [
      {
        id: 'romance_1', title: 'Hinge 上一个完美男生 / 女生',
        trigger: { minWeek: 14 },
        title_full: '"Daniel · 31 · Banking · Singapore→London"',
        body: '周二晚 11 点你在 ensuite 床上无聊滑 Hinge。突然一个 match。\n\n"Daniel · 31 · 新加坡→伦敦"。照片 4 张：健身房自拍、Maldives 海边、米其林餐厅、和小狗合影。Bio 写："Banker @ 一家美资行 (cant say which 😅) / 在伦敦 6 个月 short-term posting / 北京长大 / 喜欢 hiking + Murakami / 想认识有思想的人不只是想 brunch"。\n\n他第一句话：" 你写 cultural studies... 是真的吗？我大学差点也读那个。本科最后一年读了 Said 的 Orientalism 三遍。" 接着精准引用了一段。\n\n你愣住——这是你来伦敦 14 周遇到的第一个真正"对得上话"的人。',
        choices: [
          { label: '回他 + 开始聊', effect: { energy: 1, belonging: 4, flag: 'romance_daniel_started' },
            feedback: '你们聊到凌晨 2 点。他比你大 9 岁但思维很扎实——讲他在新加坡看 Crazy Rich Asians 的复杂感受、讲他爸妈搬到 SG 后的失语、讲他 25 岁差点辞职去读 PhD。\n\n你睡前给他发"晚安"。他回了一个月亮 emoji。\n\n你想：原来 Hinge 上不是只有 hookup 的人。' },
          { label: '太完美了 直接 unmatch', effect: { energy: 1, belonging: -1, flag: 'romance_daniel_skipped' },
            feedback: '你 unmatch 了。\n\n第二天你后悔了 5 分钟——但你想起朋友说过的话："过于完美的男生 / 女生 9 成是诈骗。"\n\n你不知道你刚才避开了什么。但你直觉是对的。' },
        ],
      },
      {
        id: 'romance_2', title: '第一次约会 cancel + Deliveroo 道歉',
        trigger: { flag: 'romance_daniel_started', minWeek: 16 },
        title_full: '"Babe so sorry, urgent NYC client call"',
        body: '聊了 2 周。每天早安晚安 + 长 voice messages。他给你介绍他妈的福建菜谱、记得你 essay deadline、跟你视频过 1 次（光线很暗 5 分钟就借故挂了，说在等 client）。\n\n你们约这周日 brunch in Mayfair (Sketch)。前一晚他发：\n\n"Babe so sorry — got an urgent NYC client call to fly out tonight 😭 will be back Wed. To make it up I sent you a small thing on Deliveroo, please order whatever you want this weekend. ❤️"\n\n你查 Deliveroo 收到 £30 voucher。',
        choices: [
          { label: '"理解 工作要紧" + 收下 voucher', effect: { wallet: 30, energy: 2, belonging: 4, flag: 'romance_daniel_invested' },
            feedback: '你回："理解。NYC 出差注意休息。" 他立刻发一长串感谢 + "等我回来一定补上"。\n\n你周日点了 Deliveroo + 在床上吃 brunch + 想他。\n\n这一刻你没注意到的事：第一次见面就出差，是 pig butchering 经典脚本里的"建立距离感 + 维持神秘 + 用钱补偿建立 reciprocity"三连。\n\n但你只是觉得 — 他真的是个忙人。' },
          { label: '"非要见到 那下周一定" 坚持', effect: { energy: -2, belonging: 0, flag: 'romance_daniel_doubted' },
            feedback: '你回："那下周一定见。我可以 flexible。"\n\n他："当然 我也想 — 但 next week 我还要去 SF 那边 client。要不 the week after?"\n\n你心里咯噔一下。但你说"好"。\n\n直觉先于理性。但你还没听直觉。' },
          { label: '直接 unmatch', effect: { energy: 0, belonging: 0, flag: 'romance_daniel_skipped' },
            feedback: '你直接 unmatch 了。\n\n他从你 Hinge 列表消失。你心里有 5 分钟"是不是太快了"——但也没再回头。\n\n后来你才知道 — 你避开了一个 6 周精心打磨的脚本。' },
        ],
      },
      {
        id: 'romance_3', title: '"Today my desk got an alpha"',
        trigger: { flag: 'romance_daniel_invested' },
        title_full: '一个突然的"投资建议"',
        body: '5 周过去了。每天早晚 voice messages。他听过你哭（你妈检查出甲状腺问题那次）。他给你买了 Headspace 1 年订阅 (£40) + 寄过来一本他喜欢的 Murakami 签名版（你拆包裹时手在抖）。\n\n他还是没 in person 见过你（每次都在出差）。\n\n今天他发来："宝 跟你讲个事——today my desk got an alpha (insider tip 不能解释具体)。下周二 BTC 必涨 ≥ 8%。我们内部 trading platform 我帮你开个号 — 你先 £200 试试 一周后 £400 提现 you can use it for that handbag you wanted ❤️"\n\n附一张 platform 截图：他自己账号余额 £127,432。还有他 IG story 转发 — 站在 Goldman 大楼前。',
        choices: [
          { label: '"我 google 一下这个 platform"（反查）', effect: { energy: -3, belonging: 6, flag: 'scam_pig_resisted' },
            feedback: '你 Google "platform 名字 + scam"。第一页 5 个 reddit 帖 + Action Fraud 警告 + 中文小红书"被骗 £30,000"。所有人描述的"男 / 女朋友"都来自不同国家但脚本一致。\n\n你反查他 4 张 Hinge 照片——3 张盗自上海某健身教练 IG。Maldives 那张是 Getty Images。Goldman 大楼前那张是 Google Street View 截图 P 上去的。\n\n你坐在床上发呆 30 分钟。然后开始截图——5 周聊天 + voice messages + 收到的 £30 Deliveroo voucher（这居然是真的，他唯一 sunk cost 的钱）+ 那本 Murakami 签名（也是真的，但是 Amazon £18 的版本）。\n\n你拉黑 + 报 Action Fraud。\n\n你一晚上 24h 没吃东西。心痛不是为他——是为那 5 周里你以为是真的的所有"晚安"。' },
          { label: '"听起来不太对，但 £200 试一下"', effect: { wallet: -500, energy: -8, belonging: -6, flag: 'scammed_pig_partial' },
            feedback: '你转了 £200。第二天 platform 显示余额 £258。第三天 £367。\n\n你又投 £300。第五天他说提现吧——但 platform 显示"需要先存入 £1,500 verification fee 才能 unlock"。\n\n你拒绝再投。Daniel 一夜之间消失。Murakami 那本书后来你发现是 Amazon 直发的（订单 ID 还在他 forward 的截图角落）。\n\n损失 £500。下个月你删了 Sainsbury\'s 基础款 + 打 Link2Ur 接了 12 单代购。' },
          { label: '"宝你说啥我听啥" 全梭 £5,000', effect: { wallet: -5000, energy: -25, belonging: -15, flag: 'scammed_pig_full' },
            feedback: '你转了 £5,000——过去 4 个月 Link2Ur 接单 + 妈妈生活费攒的全部。Platform 显示余额 £6,400。你截图发给 Daniel。\n\n他："Babe I\'m proud of you. Withdraw 需要先存 £2,000 KYC fee。"\n\n你拒了。24 小时之内 Hinge unmatch、微信 block、电话停机。\n\n你坐在床上看那个空对话框——你不知道要 block 谁，他已经不在了。\n\n你给妈打电话——说不出口，挂了。\n\n第二天 9am 还有 tutorial。Tom 在厨房做 toast 跟你说 "alright?" 你说 "alright"。\n\n那个月你删了 Sainsbury\'s basket 6 件、Tesco 改买 Value range、圣诞机票没订（CSSA 群里说"今年留下"）。妈妈下个月转账你回："这学期不用 我接单够用"——撒谎。\n\n半年后你才在 NHS 咨询那里把它讲出来。' },
        ],
      },
      {
        id: 'romance_4', title: '他消失之后',
        // 三种 ch3 outcome 都进入 — 之前只接受 resisted 路径，被骗最重的玩家拿不到任何康复 chapter。
        // 哪怕 partial/full 也需要这个 reflective beat (尤其是 NHS therapy 选项)。
        trigger: { flagAny: ['scam_pig_resisted', 'scammed_pig_partial', 'scammed_pig_full'] },
        title_full: '空空的 Hinge 列表',
        body: '一周后。"Daniel" 的 profile 在 Hinge 上消失。\n\n你打开微信对话框看到的最后一条还是他 5 周前发的 voice message："宝今天想你。" 你听了 3 秒就关了。\n\nCSSA 群里有人发了一条反诈贴——剧本和你的几乎一字不差：5 周慢热、Murakami 同款书、Goldman 大楼前的照片、最后那句"宝今天想你"。\n\n上岸了的姐：写得好 我组里有人去年被同样剧本骗 £18k\n@Lily：宝宝太勇敢了 ✨ 我下次 swipe 也警觉一点\n狗哥：靠 这种我也接过 1 次 但我直接 unmatch 没 5 周这么深\n潜水的人：（出现）记得：他们是 24/7 工厂化操作 不是个例。\n\nAditi 私聊你："You OK?"',
        choices: [
          { label: '预约 NHS 心理咨询', effect: { energy: 5, belonging: 8, flag: 'scam_pig_therapy' },
            feedback: '你给 GP 写 referral。3 周后约到 NHS 6-session CBT。\n\n第一次你 talk 了 40 分钟。咨询师没说什么，让你哭完。临走时她递给你一杯水："Same time next week."\n\n6 周后你重新打开 Hinge——这次 swipe 得很慢。' },
          { label: '跟 Aditi 单独讲一次', effect: { energy: -2, belonging: 12, npc: { aditi: 3 } },
            feedback: 'Aditi 听你讲完 1 小时没插嘴。然后说："My cousin lost £40k to one of these in 2023."\n\n她没安慰你也没评判。沉默 2 分钟。然后："Pret? My treat." 你点头。' },
          { label: '默默消化 不告诉任何人', effect: { energy: -5, belonging: -3 },
            feedback: '你没告诉任何人。3 周后还是会半夜醒来想他的 voice message。\n\n你 delete 了 Hinge 但没卸载。' },
        ],
      },
    ],
  },

  // ─────────────────────────────────────────────────────────────
  // 杀猪盘恋爱线 - 男玩家版 (scam_romance_m) - 4 章 · Diana
  // ─────────────────────────────────────────────────────────────
  // 镜像 scam_romance (Daniel)。Diana 是 31 岁香港背景的"白富美" persona，
  // 真实 pig butchering 用美貌 + 学历 + 弱势(我刚分手)做诱饵。
  scam_romance_m: {
    id: 'scam_romance_m', name: 'Hinge 上的 Diana', npc: null,
    forGender: 'male',
    chapters: [
      {
        id: 'romance_m_1', title: 'Hinge 上一个完美的 Diana',
        trigger: { minWeek: 14 },
        title_full: '"Diana · 30 · HK→London · Lawyer"',
        body: '周二晚 11 点你在床上无聊滑 Hinge。突然 super-like 一个 30 岁女生。\n\n"Diana · 30 · 香港→伦敦"。照片 4 张：律所玻璃楼前 + Cap Ferrat 度假 + 跟妹妹合照（妹妹也很好看）+ 大学毕业典礼穿学袍。Bio："Lawyer @ 一家美所 / 香港大学毕业 / 在伦敦做 secondment 半年 / 喜欢 Sally Rooney + climbing / 想认识能聊深的人"。\n\n她第一句话："你写 cultural studies — 不是讨好课件那种 是真的吗？我律所 senior 是 Sandel 学派的 我跟他每周吃午饭 他借我的 Justice 我读了三遍。"\n\n你愣住——这是 Hinge 上的女生第一次开口比你 essay 写得好。',
        choices: [
          { label: '回她 + 开始聊', effect: { energy: 1, belonging: 4, flag: 'romance_diana_started' },
            feedback: '你们聊到凌晨 2 点。她比你大 8 岁但没看穿你——她讲香港回归后她爸的政治转向、讲她妹妹得抑郁症时她半年没睡好、讲她 27 岁差点辞职去做 NGO。\n\n你睡前给她发"晚安"。她回了一颗星星。\n\n你想：原来 Hinge 上不全是颜值滤镜。' },
          { label: '太完美了 直接 unmatch', effect: { energy: 1, belonging: -1, flag: 'romance_diana_skipped' },
            feedback: '你 unmatch 了。\n\n第二天你后悔了 5 分钟。但你想起室友说过的话："过于完美的女生 + 太精准击中你的兴趣点 = 9 成是钓鱼。"\n\n你不知道你避开了什么。但你直觉是对的。' },
        ],
      },
      {
        id: 'romance_m_2', title: '第一次约会 cancel + Selfridges voucher',
        trigger: { flag: 'romance_diana_started', minWeek: 16 },
        title_full: '"Babe so sorry, urgent partner call to fly to NY"',
        body: '聊了 2 周。她每天发你早安晚安 + 长 voice notes（声音真的好听 — 中港混合的英式英语）。她记得你 essay deadline、给你推荐 Sally Rooney 新书、视频过 1 次（光线不好 5 分钟挂了"我 partner 在 call 我"）。\n\n你们约这周日 brunch in Mayfair。前一晚她发：\n\n"Babe so sorry — partner 临时让我飞 NY 跟客户开庭，要等到周三。To make it up — 我让 Selfridges 给你寄个 voucher £40 这周末买点喜欢的 ❤️"\n\n你查邮箱真收到 Selfridges £40 e-voucher。',
        choices: [
          { label: '"理解 律所就这样" + 收下', effect: { wallet: 40, energy: 2, belonging: 4, flag: 'romance_diana_invested' },
            feedback: '你回："理解。NY 飞机注意休息。" 她立刻发一长串感谢 + "回来一定补上"。\n\n你周末用 voucher 买了一双 socks + 一瓶 hand wash。在床上想她。\n\n你没注意到的事：第一次见面就出差、视频从来短、用钱补偿"建立 reciprocity"——这是 pig butchering 经典 3 步骤。\n\n但你只是觉得：她真的是个 high-flyer。' },
          { label: '"非要见到 Sunday 一定" 坚持', effect: { energy: -2, belonging: 0, flag: 'romance_diana_doubted' },
            feedback: '你回："那 Sunday 必须见。我 flexible。"\n\n她："当然 我也想 — 但 next week 还要去 SF closing 一个 deal。要不 the week after?"\n\n你心里咯噔一下。但你说"好"。\n\n直觉先于理性。但你还没听直觉。' },
          { label: '直接 unmatch', effect: { energy: 0, belonging: 0, flag: 'romance_diana_skipped' },
            feedback: '你直接 unmatch。她在你 Hinge 列表消失。\n\n你心里有 5 分钟"是不是太快了"——但也没回头。\n\n后来你才知道——你避开了一个 6 周精心打磨的脚本。' },
        ],
      },
      {
        id: 'romance_m_3', title: '"My partner gave me an alpha"',
        trigger: { flag: 'romance_diana_invested' },
        title_full: '一个突然的"投资建议"',
        body: '5 周过去了。每天早晚 voice notes。她听过你哭（你妈检查甲状腺那次）。她给你买了 Audible 1 年订阅 (£80) + 寄过来一本她 own 的 Sally Rooney 签名版（你拆包裹时手在抖）。\n\n她还是没 in person 见过你（每次都在飞）。\n\n今天她发来："Babe — 我 partner 今天给了一个 alpha。她做 PE 的 朋友圈一个 boutique platform 给 high-net-worth client 内部交易 win rate 90%+。我让她给你开个 access — 你先 £200 试试 一周后 £400 提现 你之前说想买的那个 jacket 就够了 ❤️"\n\n附 platform 截图：她自己账户 £180,432 余额。还有她 IG story 站在 Mayfair Annabel 私人会所门口。',
        choices: [
          { label: '"我 google 一下 + 反查照片"', effect: { energy: -3, belonging: 6, flag: 'scam_pig_resisted' },
            feedback: '你 Google 那个 platform。第一页 8 个 reddit 帖 + Action Fraud 警告 + 香港 MingPao 报道"被骗 ¥2M"。所有受害者描述的"男 / 女朋友"脚本一致。\n\n你反查 Diana 4 张 Hinge 照片——3 张盗自香港某 KOL Instagram。Cap Ferrat 那张是 Pinterest 模特照。Mayfair Annabel 门口那张是 Google Street View 截图 P 上去的。\n\n你坐在床上发呆 30 分钟。然后开始截图——5 周聊天 + voice notes + 收到的 £40 Selfridges voucher（这居然是真的，她唯一 sunk cost）+ 那本 Sally Rooney 签名（也是真的，但是 eBay £25 的版本）。\n\n你拉黑 + 报 Action Fraud。\n\n你一晚上 24h 没吃东西。心痛不是为她——是为那 5 周里你以为是真的的所有"晚安"。' },
          { label: '"听起来不太对，但 £200 试一下"', effect: { wallet: -500, energy: -8, belonging: -6, flag: 'scammed_pig_partial' },
            feedback: '你转了 £200。第二天 platform 显示余额 £258。第三天 £367。\n\n你又投 £300。第五天她说提现吧——但 platform 显示"需要先存 £1,500 verification fee 才能 unlock"。\n\n你拒绝再投。Diana 一夜之间消失。Sally Rooney 那本书后来你发现是 eBay 直发的（订单 ID 还在她 forward 的截图角落）。\n\n损失 £500。下个月你删了 Sainsbury\'s 基础款 + 打 Link2Ur 接了 12 单代购。' },
          { label: '"宝你说啥我听啥" 全梭 £5,000', effect: { wallet: -5000, energy: -25, belonging: -15, flag: 'scammed_pig_full' },
            feedback: '你转了 £5,000——4 个月 Link2Ur 接单 + 妈妈生活费攒的全部。Platform 显示余额 £6,400。\n\n你截图发 Diana。她："Withdraw 需要先存 £2,000 KYC fee。"\n\n你拒了。24 小时之内 Hinge unmatch、微信 block、电话停机。\n\n你坐在床上看那个空对话框——你不知道要 block 谁，她已经不在了。\n\n你给妈打电话——说不出口，挂了。\n\n第二天 9am 还有 tutorial。楼下 Tom 在厨房煎 bacon 跟你说 "alright?" 你说 "alright"。\n\n那个月你删了 Sainsbury\'s basket 6 件、Tesco 改买 Value range、圣诞机票没订（CSSA 群里说"今年留下"）。妈妈下个月转账你回："这学期不用 我接单够用"——撒谎。\n\n半年后你才在 NHS 咨询那里把它讲出来。' },
        ],
      },
      {
        id: 'romance_m_4', title: 'Diana 消失之后',
        // 三种 ch3 outcome 都进入 (resisted / partial / full)。被骗的玩家也需要这个 reflective beat
        // (NHS therapy / Marcus 啤酒 / 自己消化)，而不是直接被叙事抛弃。
        trigger: { flagAny: ['scam_pig_resisted', 'scammed_pig_partial', 'scammed_pig_full'] },
        title_full: '空空的 Hinge 列表',
        body: '一周后。Diana 的 profile 在 Hinge 上消失。\n\n你打开微信看到她最后一条 voice note："Babe 今天想你。" 你听了 3 秒就关了。\n\nCSSA 群里有人发了一条反诈帖——剧本和你的几乎一字不差：HK 律所背景、Sally Rooney 同款书、prop firm 的"导师"角色、最后那句"宝今天想你"。174 个赞——其中 60% 是男生。\n\n狗哥：兄弟 我也被加过一个 hk 律所女 当时差点 当时差点\n凯泽：我去 这个 prop firm 我表哥也踩过 £8k\n上岸了的姐：男生很少发反诈贴 这条很重要。\n新生小王：哥们 你这个让我学到了 我准备发给我爸妈\n@Lily：男生宝宝注意安全 太可怕了 ✨\n\nMarcus 私聊你："You alright, mate?"',
        choices: [
          { label: '预约 NHS 心理咨询', effect: { energy: 5, belonging: 8, flag: 'scam_pig_therapy' },
            feedback: '你给 GP 写 referral。3 周后约到 NHS 6-session CBT。\n\n第一次你 talk 了 40 分钟。咨询师没说什么，让你哭完。临走时她递给你一杯水："Same time next week."\n\n6 周后你重新打开 Hinge——这次 swipe 得很慢。' },
          { label: '跟 Marcus 单独喝杯酒', effect: { energy: -2, belonging: 12, npc: { marcus: 3 } },
            feedback: 'Marcus 听你讲完没插嘴。然后递给你 Guinness："Drink up."\n\n第二轮酒来的时候他说："Same thing happened to my flatmate. He still can\'t talk about it."\n\n你们没再聊这件事。' },
          { label: '默默消化 不告诉任何人', effect: { energy: -5, belonging: -3 },
            feedback: '你没告诉任何人。3 周后还是会半夜醒来想她的 voice note。\n\n你 delete 了 Hinge 但没卸载。' },
        ],
      },
    ],
  },

  // ─────────────────────────────────────────────────────────────
  // 美妆代购 MLM 线 - 女玩家版 (scam_cosmetic_daigou) - 3 章 · Lyn 学姐
  // ─────────────────────────────────────────────────────────────
  // 真实模板：UK 留学圈 2024 真实存在的"美妆 / 护肤 small business 代购"
  // funnel。Younique / Nu Skin / Arbonne / Monat 等品牌伪装成 personal brand。
  scam_cosmetic_daigou: {
    id: 'scam_cosmetic_daigou', name: 'Lyn 姐 · "我自己用的"', npc: null,
    forGender: 'female',
    chapters: [
      {
        id: 'daigou_1', title: 'Lyn 姐朋友圈给你点赞',
        trigger: { minWeek: 8 },
        title_full: '"小妹妹 这个 SK-II 我用了 3 年"',
        body: 'CSSA 群里一个 27 岁的"Lyn 姐 ✨"——她朋友圈是精修生活流：Selfridges 化妆品柜台、Mayfair 下午茶、Notting Hill 公寓阳台。她跟你点赞 5 条朋友圈后私聊你：\n\n"小妹妹 我看你皮肤底子好但是好像没护肤 ✨ 我自己用了 3 年的小蓝瓶 + Erborian 系列免税价我帮你拿 你这个状态用了一定加分 不加我代购微信也行 我朋友圈每周分享。"\n\n你点开她朋友圈——确实每天发护肤"测评"，看起来像一个真在用的人。',
        choices: [
          { label: '"哎好 我加你看看"', effect: { energy: -1, belonging: 2, flag: 'lyn_started' },
            feedback: '你加了她代购微信。第一周她每天发你"今日 OOTD"+ 护肤 vlog + 一些"姐妹我们要爱自己"的鸡汤。\n\n第二周她发了一支 Charlotte Tilbury Pillow Talk 唇膏（£30）作为"妹妹见面礼"，没收钱。\n\n你想：原来 UK 真的有"代购学姐"这种暖心存在。' },
          { label: '"谢谢 我 Boots 买就行"', effect: { wallet: 0, belonging: 0 },
            feedback: '你客气拒绝。Lyn 姐："了解 ❤️ 有需要随时找我"。\n\n她没再 push。但她半年后在另一个 CSSA 群里 attach 别的女生——同样的话术，同样的"妹妹我看你皮肤底子好"。\n\n你不知道你避开了什么。' },
        ],
      },
      {
        id: 'daigou_2', title: '"要不要做我们 affiliate"',
        trigger: { flag: 'lyn_started', minWeek: 14 },
        title_full: '"你这个气质做我们 partner 简直完美"',
        body: '6 周过去了。Lyn 姐每天给你点赞 + 偶尔送小样 + 听你 vent 关于学校。你跟她讲了一些蛮 personal 的事（比如你跟妈妈关系紧张）。\n\n今天她语音 30 秒：\n\n"小妹妹 跟你讲个事——其实姐姐我做的不只是代购 我做的是一个 wellness brand 的 UK partner。每周开会 我现在带 12 个 girls。我看你气质和谈吐——你做我们 partner 简直完美 而且这个收入 sky\'s the limit。我们这周二有个 onboarding tea 在我 flat 你来听一下不收钱 不参加也没事 ❤️"',
        choices: [
          { label: '去 onboarding tea', effect: { energy: -3, belonging: -1, flag: 'lyn_pitch_in' },
            feedback: '你周二去了她 Notting Hill 公寓（后来你才知道是 Airbnb）。屋里 5 个 25-30 岁女生 + 一个戴大金链子的"top-tier mentor"。\n\nMentor 站起来分享："2 年前我也是 PhD student 焦虑迷茫。现在我每个月被动收入 £8,000+。这不是销售 这是 lifestyle empowerment。"\n\n你听到 7 点。Lyn 姐单独把你拉到角落："你 Q4 能到 Silver tier。"' },
          { label: '"我去看看" 但中途撤', effect: { energy: -2, belonging: 2, flag: 'lyn_doubted' },
            feedback: '你去了 30 分钟就站起来要走。Lyn 姐："Stay for the Q&A?" 你坚持。\n\n出门后你 Google "她说的 wellness brand 名字 + scam"——第一页全是 r/antiMLM。\n\n你心里凉了——Lyn 姐 6 周给你点赞 + 送小样 + 听你 vent 都是为了这一刻。' },
          { label: '"哎这是 MLM 吧" 直接拒绝 + 群里警告', effect: { energy: -3, belonging: 6, flag: 'scam_cosmetic_resisted' },
            feedback: '你看了 voice note 5 分钟没回。然后："Lyn 姐 这是 wellness MLM 吗？我朋友被 Nu Skin 拉过 我不参加。"\n\nLyn 姐回："这不一样的 我们是 community-based..."\n\n你直接 block。\n\n回家后你发 CSSA 群警告："以美妆代购为 funnel 的 wellness MLM 已经至少 3 个不同名字 同一套话术。"\n\n@Lily：天 我半年前被「Vivi 学姐」加过 一模一样剧本 我居然真去了 Notting Hill 公寓 ✨\n上岸了的姐：funnel 6 周话术：第一周点赞、第二周送小样、第三周听你 vent、第四周开始铺生活方式、第五周邀请聚会、第六周 starter kit。识别这个节奏。\n新生小王：同学 我前天被 Cherry 学姐加了 我以为她真的是学姐\n狗哥：男生群里也有 改成 trading mentor 一个味' },
        ],
      },
      {
        id: 'daigou_3', title: '"£300 starter kit + 你的 downline"',
        trigger: { flag: 'lyn_pitch_in' },
        title_full: 'Notting Hill 阳台上的 final pitch',
        body: '聚会后 Lyn 姐留你单独聊。她 brewing 一壶 Mariage Frères tea。\n\n"妹妹 我看出来你跟其他 girls 不一样——你认真、有读 cultural studies、有 own voice。我们 starter kit £300 包 6 件 product samples + first 3 months mentorship + access to global Wellness summit Zoom。我自己 5 个月 break even。我帮你 onboard 5 个 lead 你 break even 更快。"\n\n她 push 价目表 + 团队层级图（Bronze / Silver / Gold / Platinum / Diamond）：\n\n"你 Q4 到 Silver。Q1 到 Gold。Q2 你 own life。"',
        choices: [
          { label: '"这是金字塔结构" + 拒绝 + Block', effect: { energy: -2, belonging: 6, flag: 'scam_cosmetic_resisted' },
            feedback: '你站起来。"Lyn 姐 这就是 MLM。你之前送我的小样我会还你钱。我朋友被 Nu Skin 拉过 我 google 过你们 mentor 名字——有 2 个 lawsuit。我不参加，建议你也想想自己在做什么。"\n\nLyn 姐表情瞬间冷下来："你想清楚 — 限时 quota。你不参加 我下周 invite 别人。"\n\n你："那就 invite 别人。"\n\n你 block 她。3 周后她在另一个 CSSA 群里 attach 别的女生——她甚至不记得你。' },
          { label: '交 £300 试一下', effect: { wallet: -300, energy: -10, belonging: -8, flag: 'scammed_cosmetic' },
            feedback: '你转 £300。一周后 starter kit 到了——里面是 £25 amazon 烂护肤品 + 一本 self-published 的"empowerment guide"。\n\nLyn 姐 push 你"build downline"。你试着发朋友圈一次——3 个朋友私聊你"你怎么做这个了"。你删了那条朋友圈。\n\n3 个月后你没拉到任何人。Lyn 姐从你 mentor 变成 distant。半年后她从 IG 把"Wellness Partner @ ..."那行去掉了。\n\n那盒 amazon 烂护肤品摆在书桌 2 个月。妈妈视频问你"那是什么"，你说"室友送的"。' },
          { label: '"我得想想"（缓兵）', effect: { energy: -3, belonging: 0 },
            feedback: '你说"让我考虑一周"。Lyn 姐立刻 push："spot 留给你 但下周不 confirm 就 release"。\n\n你回家后查 reddit 1 小时确认是 MLM。你不 block 她但不回。\n\n她 push 3 次后停了。3 周后她从你朋友圈消失（block 了你？）。' },
        ],
      },
    ],
  },

  // ─────────────────────────────────────────────────────────────
  // Trading Mentor 线 - 男玩家版 (scam_trading_mentor) - 3 章 · "Eric 哥"
  // ─────────────────────────────────────────────────────────────
  // 真实模板：UK 留学男生圈"Trading 群 / Forex Discord"funnel。
  // 一个看似战绩很好的 trader 拉你进群 → 几周晒单建立信任 → 引你入
  // copy-trade platform → 平台是仿盘自己开的。
  scam_trading_mentor: {
    id: 'scam_trading_mentor', name: '"Eric 哥" · 带飞 Forex', npc: null,
    forGender: 'male',
    chapters: [
      {
        id: 'mentor_1', title: 'CSSA 男生群"Eric 哥"加你',
        trigger: { minWeek: 8, flag: 'cssa' },
        title_full: '"兄弟 你这一年也算白来 不学一点交易"',
        body: 'CSSA 男生小群里有个"Eric 哥 · 27 · 留英 5 年"。他每天发战绩截图："今天 GBP/USD short 25 pips +£420"、"昨晚 BTC long +£1,800"。配文很谦虚："小赚一点 兄弟们做参考"。\n\n群里几个本科男生膜拜他。今天他突然单独加你："兄弟 我看你蛮认真的 不像那群 boba boys。我有个 Discord 我跟 4 个 brothers 在里面带带新人 不收钱 你来玩玩 ❤️" 附 Discord 邀请链接。',
        choices: [
          { label: '加 Discord 看看', effect: { energy: -1, belonging: 2, flag: 'eric_mentor_started' },
            feedback: '你加了 Discord。里面 6 个亚裔男生 23-30 岁。每天 6:30 AM Eric 哥发当日 trade plan，晚上 10 PM 复盘。\n\n第一周你只看不动 — 但 Eric 哥的"plan"看起来真的赚（截图都有时间戳 + 平台 logo）。\n\n你想：原来 trading 真的有人做出来了。' },
          { label: '"兄弟 我学业紧 谢"', effect: { belonging: 0 },
            feedback: '你客气拒绝。Eric 哥发了"了解 兄弟 加油"。\n\n他没再 push。但他半年后在另一个 CSSA 群里 add 别的男生——同样的话术。' },
        ],
      },
      {
        id: 'mentor_2', title: '"我的 broker 给我 prop firm allocation"',
        trigger: { flag: 'eric_mentor_started', minWeek: 14 },
        title_full: 'Discord voice call · 听了 1 小时',
        body: '6 周过去了。Discord 里 Eric 哥每天发 plan + 每周 voice call 1 小时讲市场。他给你看过他"broker" platform 的截图——账户 £128,000，月 P&L +£18,000。他叫你"老弟"。\n\n今天他突然 voice call 你："老弟 我今天跟 broker 谈下来 给我 $10M prop firm allocation。我有一些 spillover 给 brothers — 你我哥们关系。"\n\n他打开屏幕共享一个 platform："这个是 Singapore 持牌的 prop firm。你充 £500 入金 我给你 8x leverage 你跟我的 trade 复制。每周提现。我 take 20% performance fee 老弟你也别客气 我赚才有意义。"',
        choices: [
          { label: '"哥这个 platform 我 google 一下"', effect: { energy: -3, belonging: 4, flag: 'eric_doubted' },
            feedback: '你 Google 那个 platform 名字。\n\n第一页 Action Fraud 警告 + 中文新加坡新闻"假 prop firm 骗 SG/UK 留学生 £20M"。所有受害者都是亚洲男生 22-28 岁。\n\n你冷汗下来。Eric 哥的"截图"——你回看他每张交易截图 timestamp 错位、broker logo 是模糊的、"Singapore 持牌"那个 license 号反查发现是某真实 broker 的 — 但被嫁接到了假平台。\n\n你心里说"靠 6 周 friend 都是脚本"。' },
          { label: '"哥 我信你 入 £500"', effect: { wallet: -500, energy: -10, belonging: -6, flag: 'scammed_trading_partial' },
            feedback: '你转了 £500 入金。第二天平台显示余额 £680。Eric 哥："兄弟 你跟得很稳。"\n\n你又入 £1,000。第五天他说提现吧——但 platform 弹窗"提现需先存 £1,500 验证账户"。\n\n你拒了再投。24 小时之内 Eric 哥全部消失。\n\n你损失 £1,500。下个月 Tesco basket 砍半。' },
          { label: '"哥 我梭 £5,000"', effect: { wallet: -5000, energy: -25, belonging: -15, flag: 'scammed_trading_full' },
            feedback: '你梭了 £5,000——4 个月 Link2Ur + 妈妈生活费攒的全部。Platform 显示余额 £6,400。\n\n你截图发 Eric 哥。他："KYC fee £2,000 解锁更高 leverage。"\n\n你拒了。24h 内全部消失。Discord disband、微信 block、电话停机。\n\n你给爸打电话——说不出口，挂了。\n\n第二天还要去 supervision meeting。导师问你"是不是没睡好" 你说"昨晚做了个噩梦"。\n\n那个月你接了 28 单 Link2Ur 跑腿——Westfield Apple 代购 + 给陌生人遛狗 + Bicester 帮买 4 个 Burberry 围巾扛回伦敦。爸要给你打钱你说"不用 学校 scholarship 下来了"——撒谎。\n\n半年后你才在 NHS 咨询那里把它说出来。' },
        ],
      },
      {
        id: 'mentor_3', title: 'Eric 哥消失之后',
        trigger: { flag: 'eric_doubted' },
        title_full: 'Discord 解散通知',
        body: '一周后。Discord server 突然 deleted。Eric 哥微信号停用。CSSA 男生小群里也再没他踪迹。\n\n你回看那 6 周——他每天 6:30 AM 的 trade plan / 每周 voice call / "老弟" 这个称呼 / 那个 prop firm 屏幕共享 — 全是脚本。\n\n你发到 CSSA 男生群："警告 — Eric 哥是诈骗 Discord deleted 跑路了。"\n\n狗哥：靠 老子也加了 没充钱算我命大\n凯泽：我充了 £200 试水钱还卡里没出来\n新生小王：???? 我以为 Eric 哥是真的 我差点跟着上 £500\n上岸了的姐：兄弟们 trading mentor 真的没有人会"白送" 这是行业铁律\n潜水的人：FCA register 查 broker 牌照 30 秒能验真假。\n\n其中那个充了 £200 的男生（"老张"）单独私聊你："我充了 £3,000 还没出来 现在咋办"。',
        choices: [
          { label: '帮那个男生 step-by-step report Action Fraud', effect: { energy: -8, belonging: 18, flag: 'scam_trading_helper' },
            feedback: '你跟他视频 1 小时——教他截图聊天 + Discord 历史 + 平台 receipt + 银行 dispute + Action Fraud 报案。\n\n他第二天 update："银行 chargeback 大概能拿回 £2,500。"\n\n3 周后 CSSA 群把你的反诈帖置顶。' },
          { label: '默默删 Discord + 不告诉任何人', effect: { energy: -3, belonging: -2 },
            feedback: '你 quit 那个 Discord、删聊天记录、卸 broker app。\n\n3 周后那个男生没出来——他后来损失 £5,000 没敢报警。\n\n你后悔的 — 是没站出来。' },
        ],
      },
    ],
  },

  // ─────────────────────────────────────────────────────────────
  // 同学伪装 MLM 线 (scam_classmate) - 3 章 · Emma 学姐
  // ─────────────────────────────────────────────────────────────
  // 真实模板：UK 留学圈 2023-2024 真实存在的 networking funnel：
  // CSSA 活动后加微信 → "Women in Business" / "Lifestyle Investment" 聚会
  // → 拉你买 starter kit。常见品牌：Amway / Nu Skin / Younique / 某些 crypto
  // wellness mentor 网络。
  scam_classmate: {
    id: 'scam_classmate', name: 'Emma 学姐 · "我们一起做"', npc: null,
    chapters: [
      {
        id: 'mlm_1', title: 'CSSA 活动后加微信',
        trigger: { minWeek: 6, flag: 'cssa' },
        title_full: '"我刚才听你 Q&A 印象很深"',
        body: 'CSSA 周二晚的"留学生 career talk"结束。你刚要走，一个 26 岁穿米色西装套装的女生 Emma 追上你："Hi 学妹 / 学弟。我 LSE 经济 PhD Y2。我刚才听你那个关于 belonging 的提问印象很深。"\n\n她递给你一杯咖啡（她已经买了两杯）："我家以前不富裕——靠 freelance + 一些 investment 的方式 才让我读到 PhD。我看你状态我觉得我们可以聊聊。"\n\n她朋友圈：图书馆 / Pret / Mayfair Hyatt 茶歇 / 一些"成功女性"标签朋友。一切看起来很真。',
        choices: [
          { label: '"好 我加你微信"', effect: { energy: -1, belonging: 4, flag: 'emma_mlm_started' },
            feedback: '你加了。第一周她每天发你早安 + 推荐 podcast (Tim Ferriss, Naval) + 跟你讲她家庭故事。\n\n她比你大 4 岁，听起来很 mentor。你想：原来 LSE 真的有这种学姐。' },
          { label: '"谢谢但我赶时间"', effect: { belonging: 0 },
            feedback: '你客气拒绝。Emma 说"那以后再约"。但她加了你 WhatsApp 号——一周后给你发了一个 newsletter 链接 (你没点)。\n\n这条线没继续。但你不知道你避开了什么。' },
        ],
      },
      {
        id: 'mlm_2', title: '"Women in Business" 聚会',
        trigger: { flag: 'emma_mlm_started', minWeek: 12 },
        title_full: 'Mayfair 公寓 · 30 个亚洲女性',
        body: '6 周过去了。Emma 跟你聊得很深——她甚至帮你看了一份 essay outline（看得比一些 tutor 还认真）。你信任她。\n\n今天她邀请你参加"Women in Business London"周聚会。Mayfair 的一栋私人公寓（"我们 mentor 借给我们 host 的"）。你穿了你最贵的那件大衣。\n\n屋里 30 个 25-35 岁亚裔女性。每个手腕上都戴金链 / Cartier。一个戴大金链子的 32 岁女生 站起来分享："3 年前我也是 PhD student depressed。现在我帮 200 个 women build 6-figure passive income through our community-driven wealth platform..." 她哭了一下。掌声。\n\n你旁边一个女生握你的手："Welcome. You\'re going to love this."',
        choices: [
          { label: '"我得走了，今晚 essay deadline" + 中途撤', effect: { energy: -2, belonging: 2, flag: 'emma_doubted' },
            feedback: '你低声跟 Emma 说要走。她："Stay for the Q&A at least?" 你坚持。她送你到门口："理解。下周咖啡？"\n\n出门后你在 tube 上 Google 了那个"wealth platform"名字。第一页 reddit："/r/antiMLM" 帖子 17 条。Younique-style MLM 套路。\n\n你心里凉了一截——但你也没完全接受。Emma 真的对你很 nice 啊？' },
          { label: '"哎 这是 MLM" 直接走 + 把链接发 CSSA 群警告', effect: { energy: -3, belonging: 6, flag: 'scam_mlm_resisted' },
            feedback: '你看了 5 分钟就站起来。Emma 跟出来："你要走？" 你说："Emma 这是 MLM 对吧？" 她愣了 0.5 秒——然后职业化笑容："这是 community based wealth platform 不一样。"\n\n你说："好的 那我就不参与了。" 然后 Block。\n\n回家路上你发 CSSA 群警告：\n\n@Lily：救命 我上周还被一个叫 Lily（不是我）的拉去过 我还差点交钱 ✨\n上岸了的姐：MLM = wealth platform = community = lifestyle 都是同一个 funnel 换皮。识别要点：聚会必有"我从 £20k 到 £400k"故事 + 必有 starter kit + 必有"limited spot"。\n狗哥：这帮人最烦 我接到过 4 次邀请 都是 mayfair 公寓\n新生小王：同学 我才知道 networking 还能这么搞 我以为 networking 就是去 LSE Career fair\n凯泽：补充：r/antiMLM 上有 brand 黑名单 几乎覆盖所有这种"姐姐"' },
          { label: '坐下听完 + 跟 Emma 单独聊', effect: { energy: -3, belonging: -1, flag: 'emma_pitch_in' },
            feedback: '你听到 9 点。一个又一个亚裔女性站起来讲她们"financial transformation"。你心里有些不对劲，但 Emma 在旁边很温暖。\n\n散场前 Emma 单独把你拉到角落："I want to talk to you about joining our team." 她眼神很真挚。\n\n你说："好 详细聊一下。"' },
        ],
      },
      {
        id: 'mlm_3', title: '"£400 starter kit"',
        trigger: { flag: 'emma_pitch_in' },
        title_full: '"我看出来你有潜力"',
        body: '聚会后 Emma 把你叫到她 Mayfair 公寓 (后来你才知道是 short-term Airbnb)。她端来茶。\n\n"我看出来你有潜力——你比我刚开始时聪明 3 倍。我们 starter kit £400 包含 sample products + first month\'s mentorship + access to top mentor 的 weekly call。我自己 6 个月 break even。我帮你拉 5 个 lead 你可以 break even faster。"\n\n她把价目表 + 团队层级图给你看："Bronze, Silver, Gold, Platinum tier。你 Q4 能到 Silver。"',
        choices: [
          { label: '"这是 Pyramid scheme" + 拒绝 + Block', effect: { energy: -2, belonging: 6, flag: 'scam_mlm_resisted' },
            feedback: '你站起来。"Emma 这就是 MLM。我朋友被拉过。我 google 过你们 mentor 的名字 — 有两个 lawsuit。我不参与，建议你也想想。"\n\nEmma 表情瞬间冷下来："你想清楚 — 这是 limited time。你不参加 我下周就 invite 别人了。"\n\n你："那就 invite 别人。" 走出门。\n\n你 block 了她。3 周后她在另一个 CSSA 群里 attach 别的女生——她甚至不记得你。' },
          { label: '交 £400 试一下', effect: { wallet: -400, energy: -10, belonging: -8, flag: 'scammed_mlm' },
            feedback: '你转 £400 到她说的 stripe 链接。一周后 starter kit 到了——里面是 £30 amazon 烂护肤品 + 一本 self-published 的"成功学"小册子。\n\nEmma 让你"build downline" 拉 5 个新人。你试着发朋友圈一次——3 个朋友私聊你"你怎么做这个了"。你删了那条朋友圈。\n\n3 个月后你没拉到任何人。Emma 从你 mentor 变成 distant。半年后她从 LinkedIn 把"PhD candidate at LSE"那行去掉了 —— 她其实根本不在 LSE。\n\n你那盒 starter kit 在书桌上堆了 4 个月。某周一你把它扔了——那天还要交 5000 字 essay。' },
          { label: '"我得想想"（缓兵）', effect: { energy: -3, belonging: 0 },
            feedback: '你说"让我考虑 1 周"。Emma 立刻 push："the spot 留给你 但我下周如果你不 confirm 就 release"。\n\n你回家后查 reddit 1 小时——确认是 MLM。但你也没 block 她，只是不回。\n\n她 push 了 3 次后停了。然后她从你朋友圈消失（block 了你？）。3 周后另一个学妹问你"Emma 是谁 她加我说我们一起 networking"——你立刻给她讲了一切。' },
        ],
      },
    ],
  },

  // ─────────────────────────────────────────────────────────────
  // Link2Ur 自由职业线 (link2ur_freelance) - 从接单到自由职业职业化。
  // ─────────────────────────────────────────────────────────────
  // 设计原则：不浪漫化 freelance。每章揭示真实代价（税务/合规/visa/客户砍价）。
  // 但展示这条路的存在 —— 让玩家知道毕业后不止"投行 / 回国"两条路。
  link2ur_freelance: {
    id: 'link2ur_freelance', name: 'Link2Ur · 自由职业觉醒', npc: null,
    chapters: [
      {
        id: 'fl_1', title: '第一次想"我能不能靠这个活"',
        trigger: { flag: 'l2u_3_done', minWeek: 8 },
        title_full: '完成 3 单后的 Pret 长椅',
        body: '你坐在 Bloomsbury 的长椅上吃 meal deal。打开 Link2Ur app 看自己的接单记录：3 单 / £85 / 评分 5.0。\n\n你算了算：1 单平均 1.5 小时，£28/小时。比中餐馆 £10 高 3 倍。比写代码 internship £15 高 2 倍。\n\n你心里冒出一个念头："如果我把 essay proofread + PPT 美化做出名号——这能不能变成一份正经收入？"',
        choices: [
          { label: '认真 Google "学生签证能不能 freelance"', effect: { academic: 3, energy: -1, flag: 'freelance_curious' },
            feedback: '你查了 1 小时：\n· Tier 4 学生签证不能"自雇" (self-employed)\n· 但可以做 paid internship + freelance limited 20h/week (term time)\n· 毕业后 Graduate Visa (PSW) 可以完全自雇\n\n你打开 Notion 建了一个文档："毕业后 freelance 路线"。\n\n你想：原来这不只是"打零工"。这可能是一条路。' },
          { label: '"挣点零花就好" 关掉 app', effect: { belonging: 1 },
            feedback: '你回了 ensuite 写 essay。Link2Ur 还是偶尔接单——但你没把它当一回事。\n\n这一年还有 44 周可以重新想这件事。' },
        ],
      },
      {
        id: 'fl_2', title: '客户 referral 的诱惑',
        trigger: { flag: 'l2u_8_done' },
        title_full: '"我同事都在问哪儿找你"',
        body: '一个老客户私聊你（platform 私信）：\n\n"上次你帮我做的 PPT 我们公司 5 个同事都问我哪儿找的设计师。我可以介绍他们直接找你 — 不走 Link2Ur 抽成。一单 £50-80。我也帮你节省 platform 15% 抽佣。"\n\n你算了下：5 个客户 × £60 平均 = £300，不抽佣。但走 platform 之外有几个问题：客户付钱不可靠、没有评价系统、纯靠信任。',
        choices: [
          { label: '答应 + 但坚持先走 Link2Ur 第一单 (再决定)', effect: { wallet: 60, energy: -3, belonging: 4, flag: 'freelance_pitched' },
            feedback: '你回："谢了 但我建议第一单还是走 Link2Ur 我评价系统才能保护我们俩 之后熟了我们直接合作。"\n\n客户回："Smart kid. OK 我让他们先发到 Link2Ur 上 atag 你接。"\n\n5 个客户的第一单都走完后，3 个变成长期合作（脱离 platform）+ 2 个走丢了。你这一波多挣 £180。\n\n你开始想：我是不是该开个 LinkedIn 把这个写上去？' },
          { label: '答应 + 直接走 platform 之外', effect: { wallet: 100, energy: -2, belonging: 0 },
            feedback: '你直接答应。第一个客户 £80 现金转账 — 但第三个客户拖了 3 周才付，第五个直接消失。最后到手 £200，不如想象。\n\n但你也意识到：没有 platform protection 的 freelance 风险更高。' },
          { label: '婉拒 / 留 platform', effect: { belonging: 1 },
            feedback: '你说"还是走 platform 吧 我新手不想踩坑"。客户尊重："好 那我让他们去 platform 找你。"\n\n你少挣了一些 — 但你也保住了 Link2Ur 的评价记录，长期看更值。' },
        ],
      },
      {
        id: 'fl_3', title: '第一张 invoice + 第一次报税',
        // 之前要 flag: freelance_pitched (只在 fl_2 option 1 set)，玩家选 option 2/3
        // 后 freelance_career ending 路径被锁死。改成 l2u_8_done + minWeek:22 —— 任何
        // 走过 fl_2 (条件相同) 的玩家都能进入。BACS £350 叙事不强依赖客户 referral。
        trigger: { flag: 'l2u_8_done', minWeek: 22 },
        title_full: 'BACS 转账 £350',
        body: '你给一个 startup 做了 deck。客户 BACS 转账 £350 到你 Monzo。\n\n这是你来英国第一次靠"脑子"挣这么多钱，不是端盘子、不是代购。但你也开始焦虑：\n· 这笔钱要不要交税？\n· 学生签证 self-employed 算不算违规？\n· HMRC self-assessment 截止日是哪天？\n\n你 Google "student visa freelance UK" 翻了 30 个 reddit 帖。',
        choices: [
          { label: '注册 sole trader + 走合规路线', effect: { wallet: -50, energy: -5, academic: 2, belonging: 8, flag: 'freelance_sole_trader' },
            feedback: '你花了 1 周做这件事：\n· 在 GOV.UK 注册 self-assessment（免费）\n· 让会计学姐帮看了 1 小时（£30）\n· 学生签证下你限制 in 20h/week，记录工时（在 Excel 里手动）\n· 4 月 5 日财年截止前申报，赚得少不用真交税但要 file return\n\n这是你这一年最 boring 但最稳的一次决定。\n\n6 个月后你给爸妈说"我在英国注册了 sole trader" — 他们不太懂但听起来很正经。' },
          { label: '收了再说 (informal)', effect: { wallet: 30, energy: 1, belonging: -2, flag: 'freelance_informal' },
            feedback: '你没注册 sole trader。继续接单收钱直接进 Monzo。\n\n这一年没出问题。但你也没法堂堂正正在 LinkedIn 写"freelance designer since 2024"——因为没注册的话写出来反而风险更大。\n\n灰色地带也是地带。但路走窄了。' },
        ],
      },
      {
        id: 'fl_4', title: '第一个 client meeting · 把 day rate 念出来',
        trigger: { flag: 'freelance_sole_trader' },
        title_full: 'Zoom 上的 founder',
        body: '一个 startup founder 在 LinkedIn 上找你："看到你 portfolio。我们想找人做整套 brand identity + 6 个月 investor pitch deck。可以聊聊？"\n\nZoom 上 ta 听你 portfolio 听了 30 分钟。然后说："quote 一下你的 day rate？"\n\n你之前最贵的单是 £80。但这是 6 个月深度合作。Whitmore 上次跟你说过"Don\'t undercharge — they will not respect what you don\'t value yourself."',
        choices: [
          { label: 'Quote £600/day day rate', effect: { wallet: 0, energy: -8, belonging: 6, flag: 'freelance_premium' },
            feedback: '你深呼吸说："£600/day, project rate negotiable based on scope."\n\n沉默 3 秒。Founder："Fair. Let\'s do 4 days/month for £2,400 retainer, 6 months."\n\n总数 £14,400。\n\n挂电话你坐在椅子上没动 5 分钟。然后给妈发了条消息："今天接了一个长期项目"。她回了一个赞。' },
          { label: 'Quote £200/day（保守）', effect: { wallet: 800, energy: -3, belonging: 2 },
            feedback: '你说 £200/day。Founder 立刻"OK!"——你立刻知道自己 quote 低了。\n\n你接了项目，挣了 £4,800 / 6 个月。但你心里总有根刺：原来我可以收更多。\n\n下次再 quote 的时候你说出来"£500"——那一次客户回"That\'s actually reasonable, let\'s go."' },
          { label: '"我没经验 我们就走 platform 吧"', effect: { wallet: 200, belonging: -3 },
            feedback: '你退缩了。Founder 说："那算了 我们再看看其他人。" 然后挂了。\n\n你回去打开 Link2Ur 接了一单 £25 的 PPT。你没说错——但你想：我刚才本来可以试一次。' },
        ],
      },
      {
        id: 'fl_5', title: '毕业前的选择',
        trigger: { flag: 'freelance_premium', minWeek: 48 },
        title_full: '5 个稳定客户 · 月收入 £3000+',
        body: '4 月。毕业还有 8 周。你已经有 5 个稳定客户：3 个 startup + 2 个咨询公司。月稳定收入 £3,000-3,500。\n\nGraduate Visa 申请已交。你站在路口：\n· **继续 freelance**：自由 / 不稳 / 没 visa sponsor / 但完全自主\n· **转 corporate**：进咨询 / 投行 / 大厂 / sponsor / 但回到 9-5\n· **回国 freelance**：把伦敦客户做远程 / 国内消费低 / 但少了伦敦 ecosystem\n\n你跟林可儿 / 林楠（如果在一起）讨论。ta 说："你的选择 我支持任何一个。"',
        choices: [
          { label: '继续 freelance · 留伦敦', effect: { energy: -3, belonging: 12, flag: 'freelance_career', wallet: 0 },
            feedback: '你正式声明 freelance 主业。第一年涨到月均 £4,500。\n\n两年后你拿 ILR（Indefinite Leave to Remain）—— 你是 freelance / self-sponsored 路线拿到的。这条路在中国留学生圈里几乎没人走 — 因为不像投行 H1B 那么"显赫"。\n\n但你慢慢明白：你这一年学的不只是社会学。你学的是 "how to charge for what you know"。\n\n这条路不光鲜。但是你的。' },
          { label: '转 corporate · 找 sponsor 工作', effect: { wallet: 0, academic: 3, flag: 'freelance_to_corporate' },
            feedback: '你应聘了 BCG / McKinsey / Bain — 拿到 BCG offer。年薪 £55,000。\n\nfreelance 5 个客户全部交接走。\n\n你 25 岁就开始穿西装。但你 28 岁那年某个雨夜在 Old Street 加完班走出 office，会想起那个 Pret 长椅 —— 你 22 岁第一次算"£28/小时"那个下午。' },
          { label: '回国 freelance · 把客户做远程', effect: { wallet: 0, belonging: 8, flag: 'freelance_remote_china' },
            feedback: '你飞回北京 / 上海。继续给伦敦那 5 个客户做项目，全程 remote。\n\n国内房租 1/3，你妈做的红烧肉每周 1 次。月收入还是 £3,000+ 但花销减半。\n\n你成了那种"在伦敦读书 + 现在在国内 Linker + 客户全是英国"的稀有物种。\n\n你妈见人就说："我儿子 / 女儿在伦敦那个 app 上做 Linker。" 她不太知道这是什么。但听起来很自由。' },
        ],
      },
    ],
  },

  // ─────────────────────────────────────────────────────────────
  // ⚠ TODO · 用户后续要 review/adjust 的 Link2Ur 内容（标记于 2026-05-10）
  // 需要跟用户对齐的点：
  //   1. Priya 人设：Cambridge MBA + ex-PwC + HK 背景 —— 是否换名字/背景
  //   2. Equity 谈判数字：4% vesting 4 年 / cliff 9 月 / £40k base —— 是否真实
  //   3. cap table: CEO 28% / Priya 18% / CTO 14% / COO 12% / etc.
  //   4. Ambassador 机制: 15% commission on onboarded Linker
  //   5. Link2Ur HQ 在 Old Street + 7 人创始团队 —— 是否合理
  //   6. £5,000 first big client / £29k entry-level designer 等具体数字
  //   7. 三条 arc 之间的 mutual-exclusion vs parallel 关系
  // ─────────────────────────────────────────────────────────────
  // Link2Ur · Passion Discovered (4 章)
  // ─────────────────────────────────────────────────────────────
  // 玩家接 10+ 种不同类型 task → 觉醒"哪个我真的喜欢" → niche → 找到正式工作
  link2ur_passion: {
    id: 'link2ur_passion', name: 'Link2Ur · 发现你喜欢的事', npc: null,
    chapters: [
      {
        id: 'l2u_passion_1', title: '接了 10 种不同活之后',
        trigger: { flag: 'l2u_10_done', minWeek: 14 },
        title_full: 'ensuite 床上的 list',
        body: '凌晨 1 点。你打开 Link2Ur 后台 "我完成的"——10 种类别 摆在一起：\n\n· 代购 ×3\n· 跑腿 ×4\n· 翻译 ×1\n· PPT 美化 ×2\n· 摄影 ×1\n\n你看到那 2 单 PPT 美化——做的时候**没累**。其他做完想瘫。\n\n你心里冒出一句："靠 是不是其实我喜欢 design？"',
        choices: [
          { label: '正经分析 spreadsheet ROI + 心力对比', effect: { energy: -3, academic: 4, flag: 'l2u_passion_analyzed' },
            feedback: '你做 Excel 表：12 单 × 报酬 / 时长 / 心力消耗。结果：PPT + 摄影 + design 类心力 1.5x，但你之后**精力反而 +5**（不像跑腿做完 -10）。\n\n你存下这张表。' },
          { label: '"巧合吧" 关掉', effect: { energy: 1 },
            feedback: '你关 app 睡觉。\n\n3 周后你接第 14 单 PPT 又是 net energy positive。你这才开始相信。' },
        ],
      },
      {
        id: 'l2u_passion_2', title: '专注接 design 类 5 单',
        trigger: { flag: 'l2u_passion_analyzed', minWeek: 18 },
        title_full: '故意挑活',
        body: '你接下来 1 个月**只接 design/PPT/photo 类**。\n\n第 14 单 logo · 拒了。\n第 15 单 LinkedIn 头像 · 接。\n第 16 单 startup pitch deck · 接。\n第 17 单 婚礼跟拍 · 接。\n第 18 单 brand identity · 接。\n第 19 单 menu redesign · 接。\n\n5 单做完——你看到自己 portfolio 6 张作品挂在那里。',
        choices: [
          { label: '把 portfolio 整理成 .pdf', effect: { academic: 8, energy: -5, flag: 'l2u_passion_portfolio' },
            feedback: '你 Figma 排了 12 页 portfolio。最后一页写 "Selected work · 2024-25"。\n\n你截图发妈："妈我做了一个 portfolio。"\n\n她："发爸看。" 你爸说"看不懂 但是排版漂亮"。\n\n这是你这一年第一次让爸觉得你做的事"看得见"。' },
        ],
      },
      {
        id: 'l2u_passion_3', title: '给 Whitmore 看 portfolio',
        trigger: { flag: 'l2u_passion_portfolio', minWeek: 26 },
        title_full: 'Office hour 一个不一样的对话',
        body: 'Whitmore 周三 office hour。你带 portfolio 不是 dissertation outline。\n\n你说："Sir 我可能要转 design 不读 PhD 了。"\n\n他翻完 12 页 portfolio。沉默 15 秒。然后他说："Why?"\n\n你解释 10 单 Link2Ur 心力分析。他听完，递给你一张纸条："Pentagram 一个 partner 是我以前学生。她周三在 SOAS 客座 lecture。我引荐你。"',
        choices: [
          { label: '"Sir 谢谢"（接 referral）', effect: { academic: 6, belonging: 8, flag: 'l2u_passion_intro', npc: { whitmore: 2 } },
            feedback: 'Whitmore 给 Pentagram partner 发邮件 cc 你。她 3 天回："Coffee Friday at our Notting Hill studio?"\n\n你穿了你 best shirt 去。她翻 portfolio 5 分钟，问你 3 个问题，没说太多。\n\n临走："I\'ll connect you to Charlotte — she\'s hiring junior designer at Studio Output."' },
          { label: '"我自己 cold apply 吧"', effect: { academic: 3, energy: -3 },
            feedback: 'Whitmore 没说什么，把纸条收起来。\n\n3 个月后你 cold apply 12 家 design studio 没下文。你才意识到 — 在英国 design 圈 referral > portfolio。' },
        ],
      },
      {
        id: 'l2u_passion_4', title: 'Studio Output 面试',
        trigger: { flag: 'l2u_passion_intro', minWeek: 44 },
        title_full: '面试当天',
        body: 'Studio Output · East London 一个 industrial 改造的 design studio。'
          + '\n\nCharlotte (creative director · 38 岁英国人) 看 portfolio。她问你 portfolio 里那 6 张作品 — 每张做多久 / 客户多少 / 你做了几稿 / 改了几次。\n\n她抬头："Most graduate portfolios are student projects. Yours are 95% paid client work. That\'s extremely unusual."',
        choices: [
          { label: '诚实讲 Link2Ur 的故事', effect: { academic: 10, belonging: 8, flag: 'l2u_passion_chosen', wallet: 0 },
            feedback: '你 15 分钟讲清楚：Link2Ur 接 32 单 12 种活 → 心力分析 → 锁定 design → 5 单专攻 portfolio → Whitmore 引荐。\n\nCharlotte 听完："That\'s actually one of the smartest paths I\'ve heard from a grad in 5 years. You\'re hired. £29k entry-level. Junior designer. Start September."\n\n你出了 studio 在 Old Street 站台站了 5 分钟。然后给妈视频："妈我面上了。比 BCG 少一半 但是我能做 30 年。"\n\n妈："你说能做 30 年就够了。" 然后她哭了 5 秒。' },
          { label: '简化版 "我学到了 design"', effect: { academic: 5 },
            feedback: 'Charlotte 让你回家等。3 周没回。\n\n你 follow up 邮件被 polite reject。\n\n你那一刻知道 — 你给的 narrative 不够 strong。诚实讲完整故事更打动人。' },
        ],
      },
    ],
  },

  // ─────────────────────────────────────────────────────────────
  // Link2Ur · Daren Creator (4 章)
  // ─────────────────────────────────────────────────────────────
  // Rating 4.9+ + 30 单 → Ambassador → 高级客户 → 月入 £5k → 创业
  link2ur_daren: {
    id: 'link2ur_daren', name: 'Link2Ur · 达人创业', npc: null,
    chapters: [
      {
        id: 'l2u_daren_1', title: 'Ambassador 邀请',
        trigger: { flag: 'l2u_ambassador_accepted', minWeek: 26 },
        title_full: 'Old Street Allpress 咖啡',
        body: '周二 4pm Old Street Allpress Espresso。\n\nPriya 已经到了。她比你想象中 normal — 米色大衣 + 黑色短发 + 一台 MacBook。点了一杯 oat latte。\n\n她递给你一份印好的 Ambassador onboarding 文件——3 页 + 一份 NDA。\n\n"看完签字 — 但不急。我们先聊 1 小时再决定。"',
        choices: [
          { label: '认真问 equity 细节', effect: { energy: -3, academic: 4, flag: 'l2u_daren_negotiated' },
            feedback: 'Priya 解释：Ambassador 不是 employee 也不是 vendor。15% commission on onboarded Linker + 优先 inbox + £2k signing bonus + 一年后 evaluate 是否升级到 equity partner。\n\n你问："你们之前 invite 过几个 Ambassador？" 她："14 个。8 个走 design / consulting / 自己创业。3 个继续做 ambassador。3 个升 partner。"' },
          { label: '"我先看文件"', effect: { energy: 1 },
            feedback: '你接过文件回 ensuite 看一晚上。第二天签字回。\n\nPriya 没说什么 — 但她记住你的 pattern。' },
        ],
      },
      {
        id: 'l2u_daren_2', title: '第一个高级客户',
        trigger: { flag: 'l2u_daren_negotiated', minWeek: 30 },
        title_full: 'inbox 里一封不一样的 DM',
        body: 'Ambassador onboarding 后第 2 周。\n\n你 Link2Ur inbox：\n\n"Hi — I\'m Hannah, CEO of [一家伦敦 mental health startup]。'
          + 'Found your profile through Link2Ur Top Ambassador list。Need a full brand identity package — logo + 30-page brand guidelines + investor deck。'
          + 'Budget £5,000。Timeline 6 weeks。Can we Zoom?"\n\n你倒抽一口气。\n\n这是你 portfolio 里**最大的一单**。',
        choices: [
          { label: '认真接 + 一周内交第一稿', effect: { wallet: 5000, academic: 10, energy: -25, flag: 'l2u_daren_big_client' },
            feedback: '6 周 280 小时。你做了 12 张 logo concept、80 页 brand guidelines、investor deck 25 页。'
              + '\n\nHannah 验收时哭了 5 秒："This is exactly what we needed. I\'m going to refer you to 3 other founders in my YC cohort."\n\n£5,000 转账。一周后另外 2 个 founder DM 你。你 LinkedIn headline 改成 "Brand Identity for Mental Health Startups"。\n\n你开始有 niche 了。' },
          { label: '"我不够 senior 转给别人"', effect: { wallet: 0, energy: 3 },
            feedback: '你 polite decline。Hannah："no worries — let me know if you change your mind."\n\n2 周后你后悔。\n\n但下一单 high-tier client 已经在路上 — Ambassador list 不停推。' },
        ],
      },
      {
        id: 'l2u_daren_3', title: '雇第一个学妹',
        trigger: { flag: 'l2u_daren_big_client', minWeek: 38 },
        title_full: '你的 inbox 装不下了',
        body: '现在你 inbox 每周 12+ inquiry。你一个人做不完。\n\nPriya 上次提过："Ambassador 第二阶段 — onboard 你自己的 Linker team。"\n\n你 Link2Ur 后台看 → 8 个 "rising" rating ≥ 4.6 + 5+ 单 design 的新人。\n\n你挑了 Lin Wang — 22 岁 RCA design master Y2，rating 4.8，做过 4 单 menu redesign。',
        choices: [
          { label: '面试 Lin + 让她接 3 个 small client', effect: { wallet: 600, energy: -8, flag: 'l2u_daren_team', belonging: 8 },
            feedback: '你 Zoom Lin 30 分钟。她跟你一样——刚发现自己喜欢 design 但不敢 commit。\n\n你给她 3 个 menu redesign single £200 ($60 你抽 + £140 她拿)。\n\n第 1 单她跟你 review 5 次。第 3 单她直接 ship 客户给 5 星。\n\n你成了她 mentor。Priya 后台留言："这就是我们要的 — 你不是单个 Linker 你是 mini agency。"' },
          { label: '"我自己撑住 不雇"', effect: { wallet: 0, energy: -20 },
            feedback: '你硬扛。3 个月后 burnout。client list 砍掉一半。\n\n你那时候才意识到 — 创业不是"自己 grind 更狠"——是"知道什么时候让别人帮你 grind"。' },
        ],
      },
      {
        id: 'l2u_daren_4', title: '注册 limited company',
        trigger: { flag: 'l2u_daren_team', minWeek: 48 },
        title_full: 'Companies House',
        body: '你 monthly recurring £5,200 + 4 个 Linker 你抽 commission ≈ £800 / 月。\n\n会计学姐说："你应该开 limited company。税务上更 efficient。"\n\n你 Companies House 网站 reg 公司名 "[你的名字] Studio Ltd"。\n\n£12 registration fee。3 分钟。',
        choices: [
          { label: '点 Submit', effect: { wallet: -12, academic: 8, belonging: 15, flag: 'l2u_daren_business_launched' },
            feedback: '24 小时后邮件来："Your company [你的名字] Studio Ltd has been incorporated. Company number 14XXXXXX."\n\n你转发给妈。她："给我看看。" 你截图。她："好 妈打印出来贴墙上。"\n\n这是你 22 年人生第一个 legal entity。\n\nPriya 私聊："Congrats — 你是我 4 年看到的第 7 个 Ambassador 注册 ltd。我们投资了前 6 个 4 个 — 你要 angel investment 吗？"\n\n你笑：先稳住 再说。' },
        ],
      },
    ],
  },

  // ─────────────────────────────────────────────────────────────
  // Link2Ur · Ops Partner (3 章) · Priya 邀请你成为合伙人
  // ─────────────────────────────────────────────────────────────
  link2ur_partner: {
    id: 'link2ur_partner', name: 'Link2Ur · 合伙人 offer', npc: null,
    chapters: [
      {
        id: 'l2u_partner_1', title: 'Old Street office tour',
        trigger: { flag: 'l2u_partner_offered', minWeek: 44 },
        title_full: '一个 7 人创始团队',
        body: 'Old Street 后街一栋 industrial 改造楼，3 楼。Link2Ur HQ。\n\nPriya 在门口接你。穿牛仔裤 + 白衬衫 — 不是 corporate 那套。\n\n她带你 tour office：7 张桌 + 1 个 meeting room + 1 个小厨房（有人在煮泡面）。'
          + '\n\n"我们 7 个人。3 个 founder + 4 个 senior。CTO 在台北。COO 在 Hong Kong。你见到的这 5 个都在 London。"\n\n白板上写："Q4 OKR: 100,000 active users. Currently 67,000."',
        choices: [
          { label: '问她为什么找你', effect: { academic: 5, flag: 'l2u_partner_inquired' },
            feedback: 'Priya 直接："我们缺 1 个 face for 留学生 community — 因为创始团队都不是 first-gen international student。'
              + '你不是 — 你是。你 50 单后台数据 + Sarah/Mei/Mark 三 NPC 三国关系 + scammed 抗住 — 这是我们 product team 几个月开会都说不清楚的 user perspective。"\n\n你愣了 3 秒。她："你 22 岁 我们花 4 年才搞清楚 你直接 walks-in。"' },
        ],
      },
      {
        id: 'l2u_partner_2', title: 'Equity 谈话',
        trigger: { flag: 'l2u_partner_inquired' },
        title_full: 'Meeting room · CFO Vivian',
        body: '小 meeting room。Priya + Vivian（CFO · 35 yo 美国 CMU 校友）+ 你。\n\nVivian 摊开 cap table 给你看：'
          + '\n\nCEO Marcus 28% · Priya 18% · CTO 14% · COO 12% · 其它 senior 16% (4×4%) · ESOP pool 12%\n\n"我们 offer 你 4% from ESOP pool. vesting 4 years cliff 1 year. + £40k base salary + bonus 视 Q3 KPI。"\n\n你 google一下 4% 的 dilution 价值 — 假设 next round £30M valuation = £1.2M paper worth.\n\n但 startup 8 成失败。',
        choices: [
          { label: '"4% 太少 + 给我 6%"（谈判）', effect: { energy: -5, academic: 5, flag: 'l2u_partner_negotiated_up' },
            feedback: 'Vivian 看 Priya。Priya 点头。\n\nVivian："Marcus 同意的话 5% 是 cap。你能接吗？"\n\n你说："5% 可以。但 cliff 6 个月不是 1 年。"\n\nVivian："Counter — 9 个月。" 你说 "Deal." 握手。\n\n你在伦敦第一次 negotiate equity。' },
          { label: '"4% OK 我签"', effect: { energy: -2, academic: 3 },
            feedback: '你直接接。Vivian 推 NDA + IOI 给你签。\n\n她临走："你 negotiate 你这一年最值钱的一次 conversation 没 negotiate。下次 review 你工资我会主动加。"' },
          { label: '"我回去想 3 天"', effect: { energy: 1 },
            feedback: 'Priya："take your time. offer holds 2 weeks."\n\n你回 ensuite 跟妈视频 1 小时 + 跟 Sarah 视频 1 小时 + 自己想 3 天。然后回 yes。' },
        ],
      },
      {
        id: 'l2u_partner_3', title: '签字那天',
        trigger: { flag: 'l2u_partner_inquired', minWeek: 50 },
        title_full: 'Old Street · Day 1',
        body: '你 Old Street HQ。CEO Marcus 在小厨房煮咖啡 — 牛仔裤 + sneakers，没 CEO 派头。\n\n他递给你一杯 flat white："Welcome partner #03。" 然后把一份印好的 paper file 推过来。'
          + '\n\n10 页 partnership agreement + NDA + IP assignment + equity vesting schedule。\n\n你翻每一页都签字。最后一页是手写体 "Welcome to the team — Marcus, Priya, Vivian, Aki, Lin"（5 个签名）。\n\n签完 Marcus："Office 你的桌在那边 — Lin 跟你 sit together。她 product。你 community ops。"',
        choices: [
          { label: '签 + Marcus 握手 + 拍照', effect: { belonging: 25, wallet: 0, flag: 'l2u_partner_accepted', academic: 8 },
            feedback: '你签字时手有点抖。Marcus 注意到了 — 他没说话只是把咖啡放你手边。\n\n签完你站起来。Marcus 主动伸手握："你不会后悔的。如果后悔了 — 这屋的人都还在。"\n\n你给妈视频："妈我入职了一家 startup。"\n\n她："工资多少。" 你："£40k + 4%。" 她："4% 是啥 是奖金吗。"\n\n你笑 5 秒。然后说："是的妈 是奖金。"\n\n（这是你跟妈最长的隐瞒 — 4% 不是奖金。是 paper worth £1.2M 的股份。你想 2 年 vesting 完才告诉她。）' },
          { label: '"我考虑一下"（最后撤回）', effect: { energy: 3, flag: 'l2u_partner_accepted', belonging: 18 },
            // 之前 option 2 feedback 说"第二天给他邮件 I'll take it"——叙事接了 offer 但
            // 没 set l2u_partner_accepted flag，导致 ending 拿不到。补 flag 让叙事和 ending 对齐。
            feedback: '你说："Marcus 让我再想 1 天。"\n\n他点头："Sure. Door is open. But if you walk out now — be honest with yourself why."\n\n你回 ensuite。睡一晚上。第二天给他邮件："I\'ll take it." 你少了一晚踏实但其他没变。\n\n（Marcus 回："Cool. Onboarding 下周一。Lin 会带你。"）' },
        ],
      },
    ],
  },
};
