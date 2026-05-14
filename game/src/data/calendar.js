// 学年日历 — 真实英国硕士节奏
// 总共 52 周 = 364 天

export const ACADEMIC_CALENDAR = [
  // === Autumn Term: Week 1-12 ===
  { week: 1, type: 'welcome', label: 'Welcome Week', cn: '迎新周', requireClass: false, desc: '没有课，到处迎新活动' },
  { week: 2, type: 'term', label: 'Autumn Term', cn: '秋学期', requireClass: true },
  { week: 3, type: 'term', label: 'Autumn Term', cn: '秋学期', requireClass: true },
  { week: 4, type: 'term', label: 'Autumn Term', cn: '秋学期', requireClass: true },
  { week: 5, type: 'term', label: 'Autumn Term', cn: '秋学期', requireClass: true },
  { week: 6, type: 'term', label: 'Autumn Term', cn: '秋学期', requireClass: true },
  { week: 7, type: 'reading', label: 'Reading Week', cn: '复习周', requireClass: false, desc: '没有课，建议自习' },
  { week: 8, type: 'term', label: 'Autumn Term', cn: '秋学期', requireClass: true },
  { week: 9, type: 'term', label: 'Autumn Term', cn: '秋学期', requireClass: true },
  { week: 10, type: 'term', label: 'Autumn Term', cn: '秋学期', requireClass: true },
  { week: 11, type: 'term', label: 'Autumn Term', cn: '秋学期', requireClass: true, deadline: 'essay1' },
  { week: 12, type: 'term', label: 'Autumn Term', cn: '秋学期', requireClass: true },

  // === Christmas Vacation: Week 13-15 ===
  { week: 13, type: 'vacation_xmas', label: 'Christmas Break', cn: '圣诞假期', requireClass: false, isHoliday: true },
  { week: 14, type: 'vacation_xmas', label: 'Christmas Break', cn: '圣诞假期', requireClass: false, isHoliday: true },
  { week: 15, type: 'vacation_xmas', label: 'Christmas Break', cn: '圣诞假期', requireClass: false, isHoliday: true },

  // === Spring Term: Week 16-26 ===
  { week: 16, type: 'term', label: 'Spring Term', cn: '春学期', requireClass: true },
  { week: 17, type: 'term', label: 'Spring Term', cn: '春学期', requireClass: true },
  { week: 18, type: 'term', label: 'Spring Term', cn: '春学期', requireClass: true },
  { week: 19, type: 'term', label: 'Spring Term', cn: '春学期', requireClass: true },
  { week: 20, type: 'reading', label: 'Reading Week', cn: '复习周', requireClass: false, desc: '没有课，建议自习' },
  { week: 21, type: 'term', label: 'Spring Term', cn: '春学期', requireClass: true },
  { week: 22, type: 'term', label: 'Spring Term', cn: '春学期', requireClass: true, deadline: 'group_project' },
  { week: 23, type: 'term', label: 'Spring Term', cn: '春学期', requireClass: true },
  { week: 24, type: 'term', label: 'Spring Term', cn: '春学期', requireClass: true },
  { week: 25, type: 'term', label: 'Spring Term', cn: '春学期', requireClass: true },
  { week: 26, type: 'term', label: 'Spring Term', cn: '春学期', requireClass: true, deadline: 'essay2' },

  // === Easter Vacation: Week 27-30 ===
  { week: 27, type: 'vacation_easter', label: 'Easter Break', cn: '复活节假期', requireClass: false, isHoliday: true },
  { week: 28, type: 'vacation_easter', label: 'Easter Break', cn: '复活节假期', requireClass: false, isHoliday: true },
  { week: 29, type: 'vacation_easter', label: 'Easter Break', cn: '复活节假期', requireClass: false, isHoliday: true },
  { week: 30, type: 'vacation_easter', label: 'Easter Break', cn: '复活节假期', requireClass: false, isHoliday: true },

  // === Revision + Exams: Week 31-36 ===
  { week: 31, type: 'revision', label: 'Revision', cn: '复习周', requireClass: false, desc: '考试季，疯狂自习' },
  { week: 32, type: 'revision', label: 'Revision', cn: '复习周', requireClass: false, desc: '考试季，疯狂自习' },
  { week: 33, type: 'revision', label: 'Revision', cn: '复习周', requireClass: false, desc: '考试季，疯狂自习' },
  { week: 34, type: 'exam', label: 'Exam Week', cn: '期末考试周', requireClass: false, isExam: true, examNumber: 1 },
  { week: 35, type: 'exam', label: 'Exam Week', cn: '期末考试周', requireClass: false, isExam: true, examNumber: 2 },
  { week: 36, type: 'exam', label: 'Exam Week', cn: '期末考试周', requireClass: false, isExam: true, examNumber: 3 },

  // === Dissertation: Week 37-52 ===
  { week: 37, type: 'dissertation', label: 'Dissertation · Lit Review', cn: '论文 · 文献综述', requireClass: false, dissPhase: 'review' },
  { week: 38, type: 'dissertation', label: 'Dissertation · Lit Review', cn: '论文 · 文献综述', requireClass: false, dissPhase: 'review' },
  { week: 39, type: 'dissertation', label: 'Dissertation · Lit Review', cn: '论文 · 文献综述', requireClass: false, dissPhase: 'review' },
  { week: 40, type: 'dissertation', label: 'Dissertation · Lit Review', cn: '论文 · 文献综述', requireClass: false, dissPhase: 'review' },
  { week: 41, type: 'dissertation', label: 'Dissertation · Research', cn: '论文 · 调研', requireClass: false, dissPhase: 'research' },
  { week: 42, type: 'dissertation', label: 'Dissertation · Research', cn: '论文 · 调研', requireClass: false, dissPhase: 'research' },
  { week: 43, type: 'dissertation', label: 'Dissertation · Research', cn: '论文 · 调研', requireClass: false, dissPhase: 'research' },
  { week: 44, type: 'dissertation', label: 'Dissertation · Research', cn: '论文 · 调研', requireClass: false, dissPhase: 'research' },
  { week: 45, type: 'dissertation', label: 'Dissertation · Writing', cn: '论文 · 写作', requireClass: false, dissPhase: 'writing' },
  { week: 46, type: 'dissertation', label: 'Dissertation · Writing', cn: '论文 · 写作', requireClass: false, dissPhase: 'writing' },
  { week: 47, type: 'dissertation', label: 'Dissertation · Writing', cn: '论文 · 写作', requireClass: false, dissPhase: 'writing' },
  { week: 48, type: 'dissertation', label: 'Dissertation · Writing', cn: '论文 · 写作', requireClass: false, dissPhase: 'writing' },
  { week: 49, type: 'dissertation', label: 'Dissertation · Writing', cn: '论文 · 写作', requireClass: false, dissPhase: 'writing' },
  { week: 50, type: 'dissertation', label: 'Dissertation · Writing', cn: '论文 · 写作', requireClass: false, dissPhase: 'writing' },
  { week: 51, type: 'dissertation', label: 'Dissertation · Final Edit', cn: '论文 · 终审', requireClass: false, dissPhase: 'edit' },
  { week: 52, type: 'dissertation', label: 'Dissertation · Submission', cn: '论文 · 提交', requireClass: false, dissPhase: 'submit', deadline: 'dissertation' },
];

export function getWeekInfo(week) {
  return ACADEMIC_CALENDAR.find(w => w.week === week) || ACADEMIC_CALENDAR[ACADEMIC_CALENDAR.length - 1];
}

export const TOTAL_DAYS = 364;
export const DAILY_ACTIONS = 5;
