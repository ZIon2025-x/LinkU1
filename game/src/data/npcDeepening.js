// Late-game deepening events for the established NPC arcs.
//
// Each NPC's storyline ended on an emotional beat (Sarah Cotswolds, Aditi
// hospital, Whitmore reference letter). These are NOT new chapters — they're
// flag-gated location events that fire later in the year, giving the
// relationship a natural second wave.
//
// Triggers:
//   Sarah Cotswolds family secret  — needs cotswolds_visited (W18+)
//   Aditi dad worsens              — needs aditi rel >= 5 (W30+)
//   Aditi quits program            — needs visited_india OR aditi rel >= 8 (W42+)
//   Whitmore retiring announcement — needs whitmore rel >= 7 (W42+)
//   Whitmore last office hour      — needs `whitmore_retiring` flag (W50+)

export const NPC_DEEPENING_EVENTS = {
  flat: [
    {
      id: 'sarah_cotswolds_secret', minWeek: 18, maxWeek: 35,
      title: 'Sarah · 一个家族秘密',
      condition: ({ flags, npcRel }) => !!flags.cotswolds_visited && (npcRel.sarah || 0) >= 7,
      body: '凌晨 1 点。Sarah 给你打来视频——她一个人在家，喝了点酒。\n\n"I never told you this. The man you met at Cotswolds—my dad—he\'s not my biological dad. My mum had me with someone else before they met. He doesn\'t know I know. He\'s raised me as his since I was 2."\n\n她沉默 5 秒。"I told you because I trust you. Don\'t tell anyone, not even my mum."',
      choices: [
        { label: '"我懂。我也有不能说的事"', effect: { energy: -3, belonging: 12, flag: 'sarah_secret_kept' },
          feedback: 'Sarah 哭了一下："Thank you. Sometimes I just need to say it out loud to one person."\n\n你们没说话静静呆了 5 分钟视频。\n\n这就是英国朋友 deeper trust 的进入门——一个深夜的告白，你接住了。从此 Sarah 跟你说话方式都不一样。' },
        { label: '"You should ask your dad about it"', effect: { energy: -2, belonging: 4 },
          feedback: 'Sarah："Maybe. Not yet though." 然后她转话题聊别的。\n\n你给的是建议但她要的是 "我接住你"。下次她不会再说这种事了。' },
      ],
    },
    {
      id: 'aditi_dad_worsening', minWeek: 30, maxWeek: 42,
      // aditi_3 (rel:5) 已经引入 dad-in-hospital——这里 deepening 推进到 weeks-not-months 的
      // critical 阶段。两个 beat 相隔几周，递进逻辑成立；Link2Ur Wall echo (Screens:922
      // `aditi_supported`) 接住 option 1 路径。
      title: 'Aditi · "Weeks not months"',
      condition: ({ npcRel }) => (npcRel.aditi || 0) >= 5,
      body: 'Aditi 在 group chat 里突然安静了一周。你给她私聊："Hey, you OK?"\n\n她回："dad\'s deteriorating. doctors said weeks not months now. liver giving out."\n\n3 秒后第二条："i don\'t know what to do. dissertation due in 8 weeks."',
      choices: [
        { label: '建议她回印度 + 你帮她 cover 课', effect: { energy: -10, academic: -3, belonging: 18, flag: 'aditi_supported' },
          feedback: '你说"go. seriously. i\'ll forward you my notes for everything you miss."\n\nAditi 哭着发 voice msg："you don\'t understand what this means."\n\n她飞了。两周后她爸去世。她在印度坐了 7 天 shiva-equivalent。回来时她憔悴但 stable。\n\n她递给你一个小金属盒——印度铜。"My dad\'s. He wanted you to have it. He remembered you from the photo."\n\n你哭了。这一刻不是你 cover 的笔记的事，是别的。' },
        { label: '"You need to focus on dissertation, dad will be OK"', effect: { energy: -3, belonging: -8 },
          feedback: 'Aditi 没回。两天后她发"thanks"。\n\n两周后她爸去世——Aditi 没去印度告别。她交了 dissertation 拿了 distinction。\n\n之后你们的关系再也回不去 Heathrow 那个抱抱了。这不是恶意——这是不同 priority 的 friendship 自然流失。' },
      ],
    },
    {
      id: 'aditi_quits_program', minWeek: 42, maxWeek: 50,
      title: 'Aditi · "我要回印度照顾妈"',
      condition: ({ flags, npcRel }) => !!flags.visited_india || (npcRel.aditi || 0) >= 8,
      body: 'Aditi 来你 ensuite——眼睛红的。\n\n"I\'m withdrawing from the program. My mum can\'t live alone. I need to go home."\n\n她已经 8 个月。还差 dissertation 一个 step 就完成 MSc。\n\n"I know it\'s stupid. £24,000 学费 wasted. But I can\'t care about that anymore."',
      choices: [
        { label: '"Don\'t quit. Suspend instead—come back when ready"', effect: { energy: -5, academic: 0, belonging: 12, flag: 'aditi_suspended' },
          feedback: '你 google 了一下 "interruption of studies UK university"。学校允许她 suspend 1-2 年，回来继续。\n\nAditi 第二天去 student services 申请。被 approved。\n\n3 年后她回伦敦完成了 dissertation——你那时候已经回国，但你在 LinkedIn 上看到她毕业那天的照片。她写的 caption："To the friend who told me to suspend, not quit. Thank you."' },
        { label: '"OK. 你决定的就是对的"', effect: { energy: -3, belonging: 6 },
          feedback: 'Aditi 真的 withdraw 了。回印度。\n\n两年后她在 LinkedIn 上写自己"在 NGO 工作 + 每天陪妈妈吃饭"。她看起来 OK——但你也知道她 MSc 永远不会完成了。\n\n你没说错——但你也没尽力。这是 retrospect 才看清的差。' },
      ],
    },
  ],

  uni: [
    {
      id: 'whitmore_retiring', minWeek: 42, maxWeek: 50,
      title: 'Whitmore · "I\'m retiring in September"',
      condition: ({ npcRel }) => (npcRel.whitmore || 0) >= 7,
      body: 'Office hour。Whitmore 收尾时突然说："I should mention—I\'m retiring at the end of the academic year. This summer is my last cohort."\n\n他 65 岁。教了 38 年。你的 dissertation 是他签字 supervise 的最后一批之一。\n\n他笑："Don\'t look so dramatic. I\'ve been threatening this for 5 years."',
      choices: [
        { label: '问他退休后做什么', effect: { energy: 1, belonging: 6, flag: 'whitmore_retiring' },
          feedback: '"Read. Walk. My wife—" 他停顿一下。"My late wife and I bought a cottage in Yorkshire we never got to. I\'m going to live in it."\n\n你想起他第二章红笔批注那个房间。他从来没说过他妻子。原来"late"。\n\n"Sir, I\'m sorry."\n\n他笑了："Don\'t be. You couldn\'t have known."' },
        { label: '"That\'s the end of an era"', effect: { energy: 0, belonging: 3, flag: 'whitmore_retiring' },
          feedback: '他笑："That\'s very kind. But the era continues—just without me. As it should."\n\n你看着他收拾办公桌——38 年的书。一个人的职业生涯就在那些书里。' },
      ],
    },
    {
      id: 'whitmore_last_office_hour', minWeek: 50, maxWeek: 52,
      title: 'Whitmore · 最后一次 Office Hour',
      condition: ({ flags }) => !!flags.whitmore_retiring,
      body: '7 月某天。学校放假前。\n\nWhitmore 的办公室已经空了一半——书装在纸箱里，墙上的画拿下来了。他给你倒了杯红茶。\n\n"Right. So. Final supervision. Anything you want to ask me before I become a private citizen?"',
      // 注：之前这个事件直接在顶层挂 effect/feedback、缺 choices 数组，是整个 pool 里
      // 唯一不标准的 schema。改成标准 choices 形式，靠 EventModal 正常渲染。
      choices: [
        { label: '"三十八年。你最想让一个学生知道的一件事是什么？"',
          effect: { energy: 5, belonging: 18, flag: 'whitmore_last_meeting' },
          feedback: '他笑了——这次是真笑。他说：\n\n"Be wrong publicly. The students who succeed in this discipline are not the ones who avoid being wrong—they\'re the ones who say the wrong thing in tutorial loud enough that someone has to correct them. That\'s how you learn."\n\n你点头。他递给你一个小信封："Open this on graduation day. Not before."\n\n你回家路上一直摸那个信封。\n\n（毕业那天你打开——里面是他妻子 1985 年发表的论文 offprint，标题 *"What we owe to be wrong about"*。）' },
        { label: '"Sir，谢谢你。" 然后没问别的',
          effect: { energy: 2, belonging: 12, flag: 'whitmore_last_meeting' },
          feedback: '他点头："You\'re welcome." 然后把红茶喝完。\n\n临走时他递给你一个小信封："Open this on graduation day. Not before."\n\n你出门那一刻意识到——你刚才其实有 30 个问题想问。但你也明白，不问比问更像告别。\n\n（毕业那天你打开——里面是他妻子 1985 年发表的论文 offprint，标题 *"What we owe to be wrong about"*。）' },
      ],
    },
  ],
};
