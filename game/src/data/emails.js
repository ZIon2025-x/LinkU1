// 定时邮件 —— 按周自动到达,模拟 UK 大学 default communication channel。
//
// 每条 email 有唯一 flag,App.jsx 在 newWeek 改变时扫一遍,符合 week + 未发过的就 dispatch。
// 不像 messages(微信式),emails 强调:阅读需要主动点开,信息密度高,有正式 sender / subject。
//
// 设计原则:
// · 每周 1-2 封,不要 spam
// · 教授真名(Whitmore)、faculty office、library、careers、wellbeing 等多个 sender
// · 文案模仿真实 UK 学术邮件:正式开头 + 段落清晰 + 信息密集 + 简洁署名
// · priority: 'high' 给警告/deadline 类(界面会显示红点)
// · condition (可选):过滤,如 library_overdue 需要玩家借过书

export const SCHEDULED_EMAILS = [
  {
    id: 'welcome_module_intro',
    week: 1,
    flag: 'email_welcome_module_intro',
    from: 'whitmore', fromName: 'Prof. P. Whitmore',
    fromEmail: 'p.whitmore@soas.ac.uk',
    subject: 'Welcome to CTS6001 · Reading List + Moodle Setup',
    body: 'Dear all,\n\nWelcome to Cultural Theory (CTS6001). A few practicalities:\n\n1. Module Moodle page: bit.ly/cts6001-2024. Please enrol yourself by Friday.\n\n2. Reading list: chapter 1-2 of Foucault\'s "Discipline and Punish" before Week 1 tutorial. Available at:\n   · Senate House Library (4F, reserve copies)\n   · Moodle PDF (under "Week 1")\n   · The Bookshop (£14.99)\n\n3. Office hours: Wednesday 4-5 PM, Russell Sq room 412. Drop in.\n\n4. Tutorial groups: please check Moodle for your group assignment.\n\nLooking forward to a great term.\n\nP. Whitmore\nLecturer in Cultural Theory',
  },
  {
    id: 'reading_list_update_w2',
    week: 2,
    flag: 'email_reading_list_w2',
    from: 'whitmore', fromName: 'Prof. P. Whitmore',
    fromEmail: 'p.whitmore@soas.ac.uk',
    subject: 'Reading List Update · Week 3 (additional paper)',
    body: 'All,\n\nFor next week\'s tutorial I\'ve added Said\'s "Orientalism" (intro + ch 1) to the reading list. Apologies for the late addition — it pairs well with the Foucault material.\n\nPDF on Moodle (Week 3 folder). 28 pages, manageable.\n\nIf you have access concerns please email me directly.\n\nPW',
  },
  {
    id: 'module_eval_form_w3',
    week: 3,
    flag: 'email_module_eval_w3',
    from: 'faculty_office', fromName: 'Faculty of Arts & Humanities',
    fromEmail: 'faculty-office@soas.ac.uk',
    subject: '📝 Module Evaluation · Mid-term Feedback (5 minutes)',
    body: 'Dear Students,\n\nWe\'re collecting mid-term feedback on all modules. Please complete the Module Evaluation Form (5 minutes) by Sunday:\n\nbit.ly/soas-eval-mid-2024\n\nWhy it matters:\n· Your feedback shapes how lecturers teach the rest of the term\n· Each module coordinator reads every response\n· Students who consistently skip evaluations have been flagged in past years\n\nThanks,\nFaculty Office',
  },
  {
    id: 'tfl_oyster_arrived',
    week: 2,
    flag: 'email_oyster_arrived',
    condition: (s) => !!s.flags?.student_oyster,
    from: 'tfl', fromName: 'Transport for London',
    fromEmail: 'no-reply@tfl.gov.uk',
    subject: 'Your 18+ Student Oyster Card has been dispatched',
    body: 'Dear Customer,\n\nYour 18+ Student Oyster photocard has been dispatched and should arrive in 3-5 working days.\n\n· 30% discount on Tube/Bus/Overground/DLR fares\n· Auto-renews each academic year (provided you remain enrolled)\n· If lost: replacement £20 via tfl.gov.uk/student\n\nDo NOT activate any other Oyster card until this one arrives — they will not stack.\n\nTfL Customer Services',
  },
  {
    id: 'wellbeing_check_w5',
    week: 5,
    flag: 'email_wellbeing_w5',
    from: 'student_services', fromName: 'Student Wellbeing Service',
    fromEmail: 'wellbeing@soas.ac.uk',
    subject: 'Settling in OK? Wellbeing resources for international students',
    body: 'Dear Student,\n\nWeek 5 — about a month in. We just want to flag some resources:\n\n· 1:1 counselling: free, same-week appointments via soas.ac.uk/wellbeing\n· Drop-in sessions: Mondays 2-4 PM (no booking needed)\n· International student support group: Thursdays 6 PM (free tea + biscuits)\n· 24h crisis line: 116 123 (Samaritans, English-speaking)\n\nIf you\'re struggling — homesick, anxious, financially stressed, anything — please don\'t wait.\n\nStudent Wellbeing Service',
  },
  {
    id: 'visiting_speaker_w6',
    week: 6,
    flag: 'email_speaker_w6',
    from: 'department', fromName: 'Dept. of Anthropology',
    fromEmail: 'anthro-events@soas.ac.uk',
    subject: '🍷 Visiting Speaker: Hannah Arendt 60 Years Later (free wine)',
    body: 'Dear All,\n\nThis Thursday 6 PM, Wolfson Lecture Theatre:\n\n"On Hannah Arendt\'s \'Eichmann in Jerusalem\' — 60 Years Later"\n\nProf. Maria Stuhlmann (Humboldt, Berlin) will deliver a 50-min lecture followed by Q&A. Free wine + cheese reception afterwards (until 8 PM).\n\nOpen to all departments. No booking needed.\n\nDept. of Anthropology',
  },
  {
    id: 'careers_spring_week_w8',
    week: 8,
    flag: 'email_spring_week',
    from: 'careers', fromName: 'SOAS Careers Service',
    fromEmail: 'careers@soas.ac.uk',
    subject: '⏰ Spring Week 2025 — Deadlines Approaching',
    priority: 'normal',
    body: 'Dear MSc students,\n\nA reminder: Spring Week 2025 applications close as early as Week 12 for major firms.\n\nKey dates:\n· McKinsey Spring Insight: 15 Nov (close)\n· BCG Spring Programme: 30 Nov\n· Goldman Sachs SI: 1 Dec\n· PwC Spring Week: 15 Dec\n· Big 4 (Deloitte/EY/KPMG): rolling, starts Oct\n\nMSc students: Spring Week is targeted at penultimate-year undergrads, BUT some firms accept Masters in their summer internship pipeline. Apply now if interested.\n\nCareers Service drop-in: Wed 1-3 PM, Russell Sq.',
  },
  {
    id: 'essay1_submission_w11',
    week: 11,
    flag: 'email_essay1_submission',
    from: 'whitmore', fromName: 'Prof. P. Whitmore',
    fromEmail: 'p.whitmore@soas.ac.uk',
    subject: '📝 Essay 1 Submission Instructions',
    priority: 'high',
    body: 'All,\n\nEssay 1 (1,500 words ± 10%) is due Friday 21:00 via Turnitin.\n\nSubmission link: Moodle → CTS6001 → "Assessments" → "Essay 1".\n\nFormat:\n· PDF only (not Word)\n· Footnotes (Chicago style)\n· Filename: cohort-id_essay1.pdf\n\nLate submissions: -5 marks per 24h. After 7 days the submission is marked 0.\n\nExtenuating circumstances: apply via Student Services BEFORE the deadline if you need an extension. Retroactive applications are rarely approved.\n\nGood luck.\n\nPW',
  },
  {
    id: 'whitmore_xmas_wishes_w14',
    week: 14,
    flag: 'email_whitmore_xmas',
    from: 'whitmore', fromName: 'Prof. P. Whitmore',
    fromEmail: 'p.whitmore@soas.ac.uk',
    subject: 'Term in review · Christmas wishes',
    body: 'Dear all,\n\nA short note before the break.\n\nMost of you have submitted Essay 1 (the rest — talk to me). Reading the cohort\'s work has been the highlight of my term.\n\nFor the break:\n· Don\'t feel obligated to "study through Christmas". Rest is part of the academic year.\n· But if you want to get a head start on next term: chapters 4-6 of Bourdieu are a good place.\n\nSome of you have asked about Boxing Day office hours. The answer is no — I will be in Yorkshire with my wife. Genuinely the only week I\'m unreachable.\n\nMerry Christmas / Happy Holidays / 节日快乐.\n\nPW',
  },
];
