// Job-hunt deepening — 4-event progression for the actual interview pipeline.
//
// Existing postGrad.js had top-level beats (LinkedIn, careers fair, sponsor
// search). This adds the actual interview lifecycle: assessment centre →
// final round → offer negotiation → fallback plan when nothing lands.
//
// Flag chain:
//   sponsor_focused or gr_strategy (from postGrad)
//   first_interview_online or hirevue_done (from postGrad)
//     → assessment_centre_pwc (W43+)
//     → final_round_rejected or final_round_passed (W47+)
//     → offer_negotiation (if passed) / fallback_plan (if no offer by W50)

export const JOB_HUNT_DEEP_EVENTS = {
  uni: [
    {
      id: 'assessment_centre', minWeek: 43, maxWeek: 49,
      title: 'Assessment Centre · 全天面试',
      condition: ({ flags }) => !!flags.hirevue_done || !!flags.sponsor_focused,
      body: '你过了 PwC HireVue 第一轮。下一关：Assessment Centre。\n\n地点 More London Place。早上 9 点签到，下午 5 点结束。包含：\n· 1 小时 group exercise（你们 6 人讨论 case）\n· 1 小时 written test\n· 30 分钟 partner interview\n· 1 小时 lunch（其实是 stealth observation）',
      choices: [
        { label: 'Group exercise 主动 facilitate', effect: { energy: -15, academic: 4, wallet: -8, stress: 10, skipDays: 1, flag: 'ac_facilitator' },
          feedback: '你看出小组里 2 个人在抢话，1 个人不说话。你说 "Let\'s hear from [name] on this"——把不说话那个拉进来。partner 注意到了。\n\nFinal round 邀请 3 天后到。' },
        { label: 'Group 安静做 contributor', effect: { energy: -10, wallet: -8, stress: 8, skipDays: 1, flag: 'ac_contributor' },
          feedback: '你说话不多但每次都精准。一个 partner 课后给你 LinkedIn 加好友："Thoughtful contributor."\n\nFinal round 邀请 1 周后到——比第一种慢但还是到了。' },
        { label: '紧张 全场没说几句', effect: { energy: -18, belonging: -5, wallet: -8, stress: 14, skipDays: 1 },
          feedback: '你坐了一天没说什么。Lunch 时 partner 跟你 small talk 你也答得简短。\n\nRejection 邮件 4 天后到："We loved meeting you, but..." 这句话开头的下一句永远是 NO。' },
      ],
    },
  ],
  flat: [
    {
      id: 'final_round_rejected', minWeek: 47, maxWeek: 50,
      title: 'Final Round · "Cultural Fit"',
      condition: ({ flags }) => !!flags.ac_facilitator || !!flags.ac_contributor,
      body: 'PwC final round 是 video call with 一个 director。聊了 50 分钟——你觉得很顺。\n\n5 天后邮件到：\n\n"We were impressed with your technical skills and we know you would have brought genuine value to our team. However, after careful consideration, we have decided to proceed with another candidate who we felt was a stronger cultural fit for the team."\n\n"Cultural fit" 是英国 corporate world 的 plausible deniability 收尾词。',
      effect: { energy: -15, belonging: -8, flag: 'rejected_pwc_final' },
      feedback: '你坐在床上看了 10 分钟。然后你打开 LinkedIn——同 cohort 的英国 / 印度同学拿了 PwC offer 各 1 个。Sponsor 那个被拒的全是中国 / 越南 / 韩国学生。\n\n你能证明什么？什么都证明不了。"Cultural fit" 没法 challenge。\n\n你给妈视频。她看你脸："还有别的呢 别死磕一家。" 你点头。\n\n这一晚你哭了一会然后开始投下 5 家。这就是英国 grad job 的常态——你从 final round 出来什么都没有 但你必须明天起来继续投。',
    },
    {
      id: 'offer_negotiation', minWeek: 48, maxWeek: 51,
      title: 'Offer · £32k，能不能争 £35k',
      condition: ({ flags }) => !!flags.ac_facilitator || !!flags.ac_contributor,
      body: '某中型咨询公司给了你 verbal offer：Junior Consultant £32,000。grad scheme median 是 £35-40k——你低了 2-5k。\n\nHR 让你 24 小时内确认。\n\nCSSA 群有前辈说"中国学生不会 negotiate 是 stereotype 的根源"。',
      choices: [
        { label: '回邮件 negotiate £35k', effect: { wallet: 0, energy: -5, belonging: 6, flag: 'negotiated_offer' },
          feedback: '你写："Thank you for the offer. Given my MSc + research experience + the market median for similar roles, I was hoping for £35,000. I\'d be happy to discuss."\n\n48 小时后 HR 回："We can do £34,000. Final."\n\n你接受了。多 £2k 一年——5 分钟邮件换来。CSSA 那个前辈对的——你不问就没。' },
        { label: '直接接受 £32k', effect: { energy: 1, flag: 'accepted_first_offer' },
          feedback: '你回："Thank you, I accept." \n\nHR 内部备注（你看不到）："Offer accepted at minimum—save the bump."\n\n你之后 3 年都拿不到 £35k——每次涨薪都从 £32k 起算 percent。第一次没问 = 永远低于市场 5%。' },
      ],
    },
    {
      id: 'fallback_plan', minWeek: 50, maxWeek: 52,
      title: '没 offer · Backup 选项',
      condition: ({ flags }) => !flags.accepted_first_offer && !flags.negotiated_offer && !flags.stayed_uk_grad,
      body: '11 月底。论文交了。LinkedIn 拒信 22 封。\n\n剩下 3 个 fallback：\n1. 接受 PSW 工签 + 找 part-time 撑 6 个月（中餐馆、Bytedance UK contractor 之类）\n2. 直接回国 + 走 1 月选调 / 国企秋招 deadline\n3. 申请 PhD（DPhil 或 MPhil）——给自己再 3-4 年时间',
      choices: [
        { label: 'PSW + part-time 撑 6 个月', effect: { energy: -8, wallet: -200, flag: 'psw_part_time_grind' },
          feedback: '你接受 Mei\'s 提供的"front of house manager"职位 £14/小时。半年后你边打工边面试——一家小 fintech 给你 sponsor。\n\n你之后说："那 6 个月是这一年学到最多的——不是论文，是怎么活下来。"' },
        { label: '回国走选调 1 月报名', effect: { wallet: 0, belonging: 5, flag: 'returned_civil_service' },
          feedback: '你给妈发"订机票了"。她秒回："好。"\n\n你 1 月 15 日到家。1 月 16 日报名"区财政局"考试。3 个月后你上岸。\n\n伦敦的一年是你简历上一行字。但你心里知道——它远不止是一行字。' },
        { label: '申请 PhD · DPhil 或 MPhil', effect: { energy: -10, academic: 8, flag: 'applied_phd' },
          feedback: 'Whitmore 教授（如果他写过推荐信）回复秒同意。你提交了 3 个 program。\n\n3 月一个 LSE PhD 接收了你——funded, 4 年。\n\n你想：我从 22 岁延到 26 岁。但我也不知道 26 岁的我会不会更明白自己。也许这就是答案。' },
      ],
    },
  ],
};
