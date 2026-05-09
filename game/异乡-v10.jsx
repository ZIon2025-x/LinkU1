import React, { useState, useEffect, useRef } from 'react';

// ========================================
// 音频系统
// ========================================
class AudioEngine {
  constructor() { this.ctx = null; this.muted = false; this.ambientNodes = []; }
  init() { if (this.ctx) return; try { this.ctx = new (window.AudioContext || window.webkitAudioContext)(); } catch (e) {} }
  setMuted(m) { this.muted = m; if (m) this.stopAmbient(); }
  click() {
    if (!this.ctx || this.muted) return;
    const o = this.ctx.createOscillator(), g = this.ctx.createGain();
    o.frequency.value = 800; o.type = 'sine';
    g.gain.setValueAtTime(0.04, this.ctx.currentTime);
    g.gain.exponentialRampToValueAtTime(0.001, this.ctx.currentTime + 0.04);
    o.connect(g); g.connect(this.ctx.destination); o.start(); o.stop(this.ctx.currentTime + 0.04);
  }
  ding() {
    if (!this.ctx || this.muted) return;
    const t = this.ctx.currentTime;
    [880, 1320].forEach((f, i) => {
      const o = this.ctx.createOscillator(), g = this.ctx.createGain();
      o.frequency.value = f; o.type = 'sine';
      g.gain.setValueAtTime(0.05, t + i * 0.08);
      g.gain.exponentialRampToValueAtTime(0.001, t + i * 0.08 + 0.15);
      o.connect(g); g.connect(this.ctx.destination); o.start(t + i * 0.08); o.stop(t + i * 0.08 + 0.15);
    });
  }
  warning() {
    if (!this.ctx || this.muted) return;
    const o = this.ctx.createOscillator(), g = this.ctx.createGain();
    o.frequency.setValueAtTime(440, this.ctx.currentTime);
    o.frequency.setValueAtTime(330, this.ctx.currentTime + 0.15);
    o.type = 'square';
    g.gain.setValueAtTime(0.04, this.ctx.currentTime);
    g.gain.exponentialRampToValueAtTime(0.001, this.ctx.currentTime + 0.4);
    o.connect(g); g.connect(this.ctx.destination); o.start(); o.stop(this.ctx.currentTime + 0.4);
  }
  success() {
    if (!this.ctx || this.muted) return;
    const t = this.ctx.currentTime;
    [523, 659, 784].forEach((f, i) => {
      const o = this.ctx.createOscillator(), g = this.ctx.createGain();
      o.frequency.value = f; o.type = 'triangle';
      g.gain.setValueAtTime(0.05, t + i * 0.08);
      g.gain.exponentialRampToValueAtTime(0.001, t + i * 0.08 + 0.2);
      o.connect(g); g.connect(this.ctx.destination); o.start(t + i * 0.08); o.stop(t + i * 0.08 + 0.2);
    });
  }
  fail() {
    if (!this.ctx || this.muted) return;
    const t = this.ctx.currentTime;
    [392, 311].forEach((f, i) => {
      const o = this.ctx.createOscillator(), g = this.ctx.createGain();
      o.frequency.value = f; o.type = 'triangle';
      g.gain.setValueAtTime(0.05, t + i * 0.12);
      g.gain.exponentialRampToValueAtTime(0.001, t + i * 0.12 + 0.25);
      o.connect(g); g.connect(this.ctx.destination); o.start(t + i * 0.12); o.stop(t + i * 0.12 + 0.25);
    });
  }
  message() {
    if (!this.ctx || this.muted) return;
    const o = this.ctx.createOscillator(), g = this.ctx.createGain();
    o.frequency.value = 1200; o.type = 'sine';
    g.gain.setValueAtTime(0.04, this.ctx.currentTime);
    g.gain.exponentialRampToValueAtTime(0.001, this.ctx.currentTime + 0.1);
    o.connect(g); g.connect(this.ctx.destination); o.start(); o.stop(this.ctx.currentTime + 0.1);
  }
  startRain(intensity = 0.3) {
    if (!this.ctx || this.muted) return;
    this.stopAmbient();
    const buf = this.ctx.createBuffer(1, this.ctx.sampleRate * 2, this.ctx.sampleRate);
    const d = buf.getChannelData(0);
    for (let i = 0; i < d.length; i++) d[i] = (Math.random() * 2 - 1) * 0.5;
    const s = this.ctx.createBufferSource(); s.buffer = buf; s.loop = true;
    const f = this.ctx.createBiquadFilter(); f.type = 'lowpass'; f.frequency.value = 1200;
    const g = this.ctx.createGain(); g.gain.value = intensity * 0.12;
    s.connect(f); f.connect(g); g.connect(this.ctx.destination); s.start();
    this.ambientNodes = [s, f, g];
  }
  startQuiet() {
    if (!this.ctx || this.muted) return;
    this.stopAmbient();
    const o = this.ctx.createOscillator(); o.frequency.value = 60; o.type = 'sine';
    const g = this.ctx.createGain(); g.gain.value = 0.012;
    o.connect(g); g.connect(this.ctx.destination); o.start();
    this.ambientNodes = [o, g];
  }
  stopAmbient() {
    this.ambientNodes.forEach(n => { try { if (n.stop) n.stop(); n.disconnect && n.disconnect(); } catch (e) {} });
    this.ambientNodes = [];
  }
}
const audio = new AudioEngine();

// ========================================
// 游戏数据
// ========================================

// 学年日历系统 - 真实英国硕士节奏
// 总共 52 周 = 364 天，按真实英国学制
const ACADEMIC_CALENDAR = [
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

function getWeekInfo(week) {
  return ACADEMIC_CALENDAR.find(w => w.week === week) || ACADEMIC_CALENDAR[ACADEMIC_CALENDAR.length - 1];
}

// ========================================
// 天气系统
// ========================================

const WEATHERS = {
  sunny: { id: 'sunny', cn: '晴', emoji: '☀️', energyMod: 0, exploreMod: 2, desc: '伦敦罕见的晴天' },
  cloudy: { id: 'cloudy', cn: '多云', emoji: '☁️', energyMod: 0, exploreMod: 0, desc: '灰白的天' },
  drizzle: { id: 'drizzle', cn: '小雨', emoji: '🌧️', energyMod: -1, exploreMod: -1, desc: '伦敦标配' },
  rain: { id: 'rain', cn: '大雨', emoji: '⛈️', energyMod: -3, exploreMod: -3, desc: '不想出门' },
  fog: { id: 'fog', cn: '雾', emoji: '🌫️', energyMod: -1, exploreMod: 0, desc: '雾里看不见对面的人' },
  snow: { id: 'snow', cn: '雪', emoji: '❄️', energyMod: -2, exploreMod: 4, desc: '伦敦少见的雪' },
};

function generateWeekWeather(week) {
  // 根据季节调整概率
  const winterWeeks = [9,10,11,12,13,14,15,16];
  const springWeeks = [17,18,19,20,21,22,23,24,25,26];
  const summerWeeks = [27,28,29,30,31,32,33,34,35,36,37,38];

  const r = Math.random();
  if (winterWeeks.includes(week)) {
    if (r < 0.30) return 'cloudy';
    if (r < 0.55) return 'drizzle';
    if (r < 0.70) return 'rain';
    if (r < 0.80) return 'snow';
    if (r < 0.90) return 'fog';
    return 'sunny';
  }
  if (springWeeks.includes(week)) {
    if (r < 0.30) return 'sunny';
    if (r < 0.60) return 'cloudy';
    if (r < 0.85) return 'drizzle';
    if (r < 0.95) return 'fog';
    return 'rain';
  }
  if (summerWeeks.includes(week)) {
    if (r < 0.55) return 'sunny';
    if (r < 0.80) return 'cloudy';
    if (r < 0.95) return 'drizzle';
    return 'rain';
  }
  // 秋
  if (r < 0.25) return 'sunny';
  if (r < 0.55) return 'cloudy';
  if (r < 0.85) return 'drizzle';
  if (r < 0.95) return 'fog';
  return 'rain';
}

// 天气专属事件（仅在特定天气触发）
const WEATHER_EVENTS = [
  { id: 'london_fog', weather: 'fog', title: '伦敦雾',
    body: '能见度只有 5 米。你走在街上，对面的人是一个模糊的影子。这才是文学里写的伦敦。',
    minWeek: 8,
    choices: [
      { label: '在公园里走一走', effect: { energy: -3, belonging: 8 },
        feedback: '你在 Hyde Park 走了一小时。雾让你和这座城市达成了一种共谋——彼此都看不太清，彼此都不打扰。' },
      { label: '回家不出门', effect: { energy: 5, belonging: -2 },
        feedback: '你蜷在公寓里读了一下午书。窗外白茫茫一片，像被擦掉的世界。' },
    ] },
  { id: 'snow_day', weather: 'snow', title: '伦敦下雪了',
    body: '伦敦的雪很少，但今天下了。整个城市突然变安静。',
    minWeek: 9,
    choices: [
      { label: '出门散步', effect: { energy: 3, belonging: 8 },
        feedback: '英国人比你还激动，他们在堆只有半个足球大的雪人。你笑了。这一刻你的家乡在心里，但你的脚在伦敦的雪里。' },
      { label: '在窗边看', effect: { energy: 5, belonging: 0 },
        feedback: '你想起北方老家的雪。这里的雪不一样，落下来就化了。但也很美。' },
    ] },
  { id: 'rare_sun', weather: 'sunny', title: '难得的晴天',
    body: '12 月。整个伦敦终于看到了太阳。气象局说"罕见"。所有人都涌出门。',
    minWeek: 9, repeatable: true,
    choices: [
      { label: '把握住，去公园', effect: { energy: 12, belonging: 6 },
        feedback: 'Hyde Park 全是人。每个人脸上都带着"终于"的表情。你不戴墨镜也眯着眼睛——你的眼睛已经习惯了灰色的天。' },
    ] },
  { id: 'tube_flooded', weather: 'rain', title: '地铁因雨停运',
    body: '大雨。Bakerloo 线宣布停运，原因是"漏水"。你看了看时间，离 tutorial 还有 40 分钟。',
    minWeek: 4,
    choices: [
      { label: '咬牙打 Uber (£25)', effect: { wallet: -25, academic: 3 },
        feedback: '你按时到了。但下个月预算又紧了。' },
      { label: '走 + 公交，迟到', effect: { energy: -10, academic: -3 },
        feedback: '你迟到了 25 分钟。Whitmore 看了你一眼。你脸红了。' },
    ] },
];

// ========================================
// 节日系统
// ========================================

const FESTIVALS = {
  6: { id: 'halloween', cn: '万圣节', emoji: '🎃', desc: '英国人在装鬼' },
  18: { id: 'spring_festival', cn: '春节', emoji: '🧧', desc: '微信群在抢红包' },
  19: { id: 'valentines', cn: '情人节', emoji: '💝', desc: '伦敦到处是玫瑰' },
  23: { id: 'mothers_day', cn: '英国母亲节', emoji: '💐', desc: '你妈不知道这天' },
  44: { id: 'notting_hill', cn: 'Notting Hill 嘉年华', emoji: '🎉', desc: '加勒比节日' },
};

const FESTIVAL_EVENTS = {
  halloween: {
    title: '万圣节夜', emoji: '🎃',
    body: '宿舍楼里所有英国人都装扮起来了。Sarah 是个吸血鬼，Tom 是 Joker。你穿着一件普通的卫衣，站在门口。',
    choices: [
      { label: '随便戴个面具去 party', effect: { energy: -8, belonging: 8, wallet: -15 },
        feedback: '你 £15 在 Tesco 买了个塑料面具，跟着他们去了 student union 的 Halloween party。你跳得不太好，但你没逃跑。这个进步比想象中大。' },
      { label: '说"我不太懂这个节日" 推掉', effect: { energy: 3, belonging: -6 },
        feedback: '你回房间看了一晚上视频。窗外尖叫声、笑声不断。你想，再过 10 年，你会后悔今晚吗？大概会。' },
    ],
  },
  valentines: {
    title: '2 月 14 日', emoji: '💝',
    body: 'Pret 把咖啡杯换成红色的。地铁里的情侣比平时多三倍。你刷着小红书，全是"我男朋友 / 女朋友送的礼物"。',
    choices: [
      { label: '给自己买一束花', effect: { wallet: -15, energy: 5, belonging: 4 },
        feedback: '£15 从 Sainsbury\'s 买的。粉色玫瑰加满天星。你回家把它们插进一个 Tesco Meal Deal 的塑料瓶里。然后看着它们笑了。' },
      { label: '去图书馆假装没事', effect: { energy: -5, academic: 3, belonging: -3 },
        feedback: '图书馆里跟你一样的人比平时多。某种说不出来的、单身留学生的隐秘同盟。' },
      { label: '约 Aditi/王凯/Sarah 一起吃饭', effect: { energy: 3, wallet: -25, belonging: 12 },
        feedback: '你们三个/四个在中餐馆挤一桌。"Forever alone party!" Aditi 举杯。你笑出声。这是你今年最好的 Valentine\'s。' },
    ],
  },
  mothers_day: {
    title: '英国的母亲节', emoji: '💐',
    body: '你刷 Instagram。所有英国朋友都在发"Happy Mother\'s Day"。你妈不知道这天——中国母亲节是 5 月。',
    choices: [
      { label: '提前给妈妈打电话', effect: { energy: -3, belonging: 12 },
        feedback: '你说："妈，今天是英国的母亲节。" 她笑了："那我今年提前过了。" 然后她沉默几秒，"早点睡 别熬夜。"' },
      { label: '什么都不做', effect: { energy: 0, belonging: -3 },
        feedback: '你刷完朋友圈关了手机。你想，等到 5 月那天再说。但你也知道，如果你今天没想到她，5 月那天她也未必能感到。' },
    ],
  },
  spring_festival: {
    title: '大年三十', emoji: '🧧',
    body: '伦敦时间下午 4 点。北京时间凌晨 12 点。微信群里在抢红包，你妈在视频里给你看年夜饭。',
    choices: [
      { label: '点一份外卖庆祝', effect: { wallet: -25, energy: 6, belonging: 4 },
        feedback: '£25 的中餐外卖。味道不太对。但你打开淘宝直播看春晚。这就是你第一次在国外的春节。' },
      { label: '约几个中国同学一起包饺子', effect: { wallet: -40, energy: 10, belonging: 18 },
        feedback: '你们五个人在某个人家里包饺子。皮厚馅少，但这是你们的春节。结束后你走在伦敦街上，第一次觉得这里没那么外国。' },
    ],
  },
};

// ========================================
// 群聊系统
// ========================================

const GROUP_MEMBERS = [
  { id: 'shang_an', name: '上岸了的姐', avatar: '岸', color: '#9080b8', role: 'PhD Y3 · 心灵鸡汤生产者' },
  { id: 'gou_ge', name: '狗哥', avatar: '狗', color: '#c4615a', role: '永远在抢黄标' },
  { id: 'lily', name: '@Lily', avatar: 'L', color: '#d4a4c0', role: '小红书风' },
  { id: 'kaize', name: '凯泽', avatar: '凯', color: '#7a8a6a', role: '情商欠费但热心' },
  { id: 'xiao_wang', name: '新生小王', avatar: '王', color: '#d4b070', role: '什么都问' },
  { id: 'qian_shui', name: '潜水的人', avatar: '?', color: '#666', role: '从来不说话' },
];

// 群消息池 - 按周触发
const GROUP_MESSAGES = [
  { week: 2, members: ['xiao_wang', 'gou_ge', 'shang_an'],
    messages: [
      { from: 'xiao_wang', text: '请问大家... Tesco 几点贴黄标啊？' },
      { from: 'gou_ge', text: '8:30 之后开始 别问 我去过 100 次' },
      { from: 'shang_an', text: '别老抢黄标 自己做饭便宜健康' },
      { from: 'gou_ge', text: '@上岸了的姐 你 PhD 学校管饭吧' },
    ] },
  { week: 4, members: ['lily', 'gou_ge', 'kaize'],
    messages: [
      { from: 'lily', text: '今天发现个超棒的下午茶 Sketch 真的人均艺术品 ✨' },
      { from: 'kaize', text: '人均多少' },
      { from: 'lily', text: '£75 左右吧 但值得 真的' },
      { from: 'gou_ge', text: '£75 我能买一周的菜' },
    ] },
  { week: 6, members: ['xiao_wang', 'kaize'],
    messages: [
      { from: 'xiao_wang', text: '想家了 今天导师又把我名字念错了 第三次' },
      { from: 'kaize', text: '常事 我都改英文名了 叫 Kevin' },
      { from: 'xiao_wang', text: '我不想改' },
      { from: 'kaize', text: '那就教育他' },
    ] },
  { week: 8, members: ['shang_an', 'lily'],
    messages: [
      { from: 'shang_an', text: '群里今晚有人 Hyde Park 看烟花吗 Bonfire Night' },
      { from: 'lily', text: '我去！穿什么暖和啊？' },
      { from: 'shang_an', text: '羽绒服+围巾+帽子。伦敦 11 月夜里很冷。' },
    ] },
  { week: 10, members: ['gou_ge', 'kaize', 'xiao_wang'],
    messages: [
      { from: 'gou_ge', text: '紧急求助：地铁罢工 明天 tutorial 怎么办' },
      { from: 'kaize', text: '走路+公交 提前两小时' },
      { from: 'xiao_wang', text: '请假吧 又不是不能 zoom' },
      { from: 'gou_ge', text: '我们专业不能 zoom' },
    ] },
  { week: 13, members: ['lily', 'shang_an', 'kaize', 'xiao_wang'],
    messages: [
      { from: 'lily', text: '圣诞了 大家都怎么过？' },
      { from: 'shang_an', text: '回家。每年都回。机票贵也回。' },
      { from: 'kaize', text: '留下来打工 中餐馆圣诞旺季' },
      { from: 'xiao_wang', text: '一个人在伦敦... 可能去看个电影' },
      { from: 'lily', text: '@新生小王 别一个人 我们组个局' },
    ] },
  { week: 18, members: ['gou_ge', 'shang_an', 'lily'],
    messages: [
      { from: 'gou_ge', text: '大年三十快乐！群里都在哪？' },
      { from: 'shang_an', text: '伦敦' },
      { from: 'lily', text: '我已经回国了 现在在三亚 [图片]' },
      { from: 'gou_ge', text: '@Lily 求别炫了' },
    ] },
  { week: 23, members: ['shang_an', 'kaize'],
    messages: [
      { from: 'shang_an', text: '大家提醒下 今天英国母亲节 给妈妈发个消息' },
      { from: 'kaize', text: '中国母亲节是 5 月不是吗' },
      { from: 'shang_an', text: '都过 多过几次有什么不好' },
    ] },
  { week: 31, members: ['xiao_wang', 'gou_ge', 'shang_an'],
    messages: [
      { from: 'xiao_wang', text: '考试周... 我感觉我考不过' },
      { from: 'gou_ge', text: '我觉得我也是 已经躺平' },
      { from: 'shang_an', text: '别躺。 真的 别躺。 我那时候挂了一门重修花了 £4500' },
      { from: 'xiao_wang', text: '😱' },
    ] },
  { week: 37, members: ['kaize', 'lily', 'qian_shui'],
    messages: [
      { from: 'kaize', text: '论文季开始 大家加油' },
      { from: 'lily', text: '我已经写了一万字了 ✨' },
      { from: 'kaize', text: '我两个字 [doge]' },
      { from: 'qian_shui', text: '...' },
      { from: 'kaize', text: '潜水的居然说话了 ！' },
    ] },
  { week: 50, members: ['shang_an', 'gou_ge', 'lily', 'xiao_wang'],
    messages: [
      { from: 'gou_ge', text: '论文交了 解放！！' },
      { from: 'lily', text: '终于' },
      { from: 'shang_an', text: '恭喜大家。这一年不容易。' },
      { from: 'xiao_wang', text: '突然觉得有点舍不得离开伦敦' },
      { from: 'shang_an', text: '都会舍不得的。这就是留学。' },
    ] },
];

// ========================================
// 可添加的"陌生人"留学生池
// ========================================

const STRANGERS = [
  {
    id: 'xiao_li', name: '小李', avatar: '李', color: '#a87fb8',
    role: '传媒系 · 爱发美食照',
    metAt: 'mei',
    encounterTitle: '中餐馆等位',
    encounterBody: '你在 Mei\'s 等位置。隔壁桌一个戴眼镜的女生 / 男生主动转过头："学弟/学妹？我看你像第一年的。我小李，传媒的。"',
    welcomeMsg: '大家好！刚加群 我小李 传媒的 ✨',
  },
  {
    id: 'a_qiang', name: '阿强', avatar: '强', color: '#7a8a6a',
    role: '电子工程 · 表情包大户',
    metAt: 'tesco',
    encounterTitle: 'Tesco 排队认出来',
    encounterBody: '排队结账时，前面一个穿运动服的男生 / 女生回头看你："你那个袋子里是老干妈吧？我也买了三瓶。" 他递给你扫码：「拉你进个群？」',
    welcomeMsg: '[doge]',
  },
  {
    id: 'tingting',
    name: '婷婷', avatar: '婷', color: '#d4a4c0',
    role: 'KCL · 经济学',
    metAt: 'pub',
    encounterTitle: 'Pub 听到熟悉的中文',
    encounterBody: 'Pub 角落里几个中国女生在大笑。其中一个看到你，挥手："Hey 学妹/学弟 一个人？过来一起啊！"',
    welcomeMsg: '哈喽 我婷婷 KCL 经济的 群里多关照',
  },
  {
    id: 'lao_zhou', name: '老周', avatar: '周', color: '#9a7050',
    role: '40 岁 · 第二次留学',
    metAt: 'library',
    encounterTitle: '图书馆夜里搭讪',
    encounterBody: '凌晨 1 点的图书馆。一个 40 岁左右的男人坐在你旁边，看你电脑屏幕："你也写到这章了？我比你更难——我儿子今年高考。"',
    welcomeMsg: '大家好。我老周。不太会用群。多关照。',
  },
  {
    id: 'da_jiang',
    name: '大江', avatar: '江', color: '#c4615a',
    role: '健身狂魔 · 商科',
    metAt: 'park',
    encounterTitle: 'Hyde Park 跑步偶遇',
    encounterBody: '一个壮硕的男生跑过你，回头："学弟 / 学妹 也是中国的？跑这条路我天天看到你。" 然后他递了一个二维码。',
    welcomeMsg: '群里好啊 我大江 健身搭子求带',
  },
  {
    id: 'lulu',
    name: '露露', avatar: '露', color: '#d4b070',
    role: 'Goldsmiths · 视觉艺术',
    metAt: 'tate',
    encounterTitle: 'Tate Modern 看画时',
    encounterBody: 'Rothko 厅里你站着发呆。旁边一个女生 / 男生说："美吧。" 你点头。她说："我每周都来。我露露 Goldsmiths 学画的。要不要加个微信？"',
    welcomeMsg: '我露露 ✨ 喜欢画画 喜欢安静的人',
  },
];

// ========================================
// @你事件池（群里有人 @ 你需要回复）
// ========================================

const AT_YOU_EVENTS = [
  {
    id: 'at_xiaowang_yellow',
    week: 3,
    askerId: 'xiao_wang',
    title: '@新生小王 在群里 @你',
    setup: '群里聊到 Tesco 黄标。',
    askerMsg: '@你 学长/学姐 你买黄标的话 8:30 真的有吗 我去过两次都没赶上',
    choices: [
      { label: '认真回复 8:30 是看分店，Sainsbury\'s 是 7 点', effect: { energy: -2, belonging: 5 },
        feedback: '你打了一长段。新生小王回："谢谢学长/学姐 太详细了 ❤️"。狗哥也跟一句："小王下次跟我去 我带你薅。"' },
      { label: '简单一句 "看分店 试试 7-9 点"', effect: { energy: 0, belonging: 2 },
        feedback: '小王回了个"好嘞 谢谢学长/学姐"。' },
      { label: '装没看见', effect: { energy: 1, belonging: -3 },
        feedback: '半小时后狗哥回了。你刷手机时小王已经被狗哥带着去抢了。你想：我那一句话 30 秒就能打完。但我没。' },
    ],
  },
  {
    id: 'at_lily_camden',
    week: 7,
    askerId: 'lily',
    title: '@Lily 看到你了',
    setup: '周末群里没什么消息。突然 Lily @你。',
    askerMsg: '@你 我刚在 Camden 看到一个超像你的人哈哈哈是你吗',
    choices: [
      { label: '"是我！下次约一起"', effect: { energy: -1, belonging: 4 },
        feedback: 'Lily："好啊 你看起来好瘦 多吃 ✨" 你笑了一下。Lily 总有一种把人捧得有点不知所措的能力。' },
      { label: '"不是 hhh 但我经常去 Camden"', effect: { energy: 0, belonging: 2 },
        feedback: 'Lily："好可惜 那有空一起去？" 你说"好"。但你们都没真的约。' },
      { label: '已读不回', effect: { energy: 1, belonging: -2 },
        feedback: 'Lily 没再发。你想，是的，也许她只是顺嘴说说，但她@了你。' },
    ],
  },
  {
    id: 'at_kaize_plagiarism',
    week: 10,
    askerId: 'kaize',
    title: '凯泽紧急求助',
    setup: '凌晨 11 点。群里突然爆出一条消息。',
    askerMsg: '@所有人 救命 我 essay 被 Turnitin 标了 30%重复 我要被 academic misconduct 调查 怎么办 ',
    choices: [
      { label: '私聊他，把你查到的流程告诉他', effect: { energy: -8, belonging: 12, flag: 'kaize_friend' },
        feedback: '你私聊了凯泽 1 小时。给他列了"先准备 reference + 写 letter of explanation + 找 academic adviser"的清单。\n\n第二天他去开了 hearing。一周后他在群里发："凯泽要请大家吃饭。" 上岸了的姐 @你："那个晚上你的耐心他记住了。" 你愣了一下——原来上岸了的姐知道。' },
      { label: '群里发"找学院 academic office 当面谈"一句话', effect: { energy: -1, belonging: 3 },
        feedback: '凯泽回了"好的 谢谢谢谢"。但你不知道他后来怎么样。' },
      { label: '不回复', effect: { energy: 0, belonging: -5 },
        feedback: '上岸了的姐主动私聊了凯泽。你后来在群里看到他化险为夷的报告。某种隐隐的羞愧。' },
    ],
  },
  {
    id: 'at_gouge_loan',
    week: 14,
    askerId: 'gou_ge',
    title: '狗哥借钱',
    setup: '圣诞前。群里突然一句。',
    askerMsg: '@你 哥们 / 姐妹 能借我 £50 吗 月底房租差一点 周五 student finance 一发就还',
    choices: [
      { label: '借', effect: { wallet: -50, belonging: 6, energy: -1 },
        feedback: '你转了 £50。周五狗哥真的还了，还多发了 £5："请你喝杯咖啡。" 你想：原来不是所有人都靠不住。' },
      { label: '"我也紧 但能借你 £20"', effect: { wallet: -20, belonging: 3 },
        feedback: '狗哥说"够了够了 谢了哥们 / 姐们"。他周五还了 £20，没多给。' },
      { label: '"我自己也紧 抱歉"', effect: { belonging: -1 },
        feedback: '你以为狗哥会冷下来，但他回了"理解理解"。然后群里换了话题。' },
    ],
  },
  {
    id: 'at_gossip_sarah',
    week: 12,
    askerId: 'gou_ge',
    title: '群里有人八卦 Sarah',
    condition: ({ npcRel }) => (npcRel.sarah || 0) >= 5,
    setup: '群里突然有人 @ 你。',
    askerMsg: '@你 哥们 我看你朋友圈那个金发的 Sarah 是不是 Sarah Whitmore 啊？她爸是不是出版业的那个？',
    choices: [
      { label: '"她姓不是 Whitmore"（保护朋友隐私）', effect: { belonging: 5, npc: { sarah: 1 } },
        feedback: '狗哥："哦 不是啊 我看错了。" 但你心里有点不是滋味——为什么大家会以为你和 Sarah 之间是因为她爸是谁。' },
      { label: '"是的 怎么了"（轻易出卖隐私）', effect: { belonging: -3, npc: { sarah: -2 } },
        feedback: '狗哥："那你混得可以啊。" 之后群里几个人都开始打听 Sarah。你不知道她以后会不会知道是你说的。' },
      { label: '不回复', effect: { belonging: 1 },
        feedback: '你装作没看见。狗哥半小时后撤回了那条 @。' },
    ],
  },
  {
    id: 'at_shangan_phd',
    week: 25,
    askerId: 'shang_an',
    title: '上岸了的姐私下 @你',
    condition: ({ stats }) => stats.academic >= 60,
    setup: '春学期末。群里有人聊 PhD 申请。上岸了的姐突然 @ 你。',
    askerMsg: '@你 你最近的 essay 我们 supervisor 提过。我们组今年有 1 个 PhD funded 名额 你考虑过读博吗',
    choices: [
      { label: '"我从来没想过 但我可以了解一下"', effect: { energy: 3, academic: 4, belonging: 8, flag: 'phd_offer_open' },
        feedback: '上岸了的姐私聊你发了详细信息和申请截止日期。你看完愣了 1 小时。原来你的 essay 真的有人在认真读。' },
      { label: '"我想找工作"', effect: { belonging: 2 },
        feedback: '上岸了的姐："理解。如果改变主意了告诉我，截止前都行。"' },
      { label: '"我配吗？"', effect: { energy: -2, belonging: 3 },
        feedback: '上岸了的姐："如果你不配 我不会 @你。" 你看着这一句话看了很久。' },
    ],
  },
  {
    id: 'at_xiaowang_goodbye',
    week: 47,
    askerId: 'xiao_wang',
    title: '新生小王要回国',
    setup: '群里安静了一周。突然新生小王 @所有人。',
    askerMsg: '@所有人 我 quit 了 不读了 下周回国 这一年谢谢大家 @你 你之前回我的那些 我都记着',
    choices: [
      { label: '"等等 见一面再走？"', effect: { energy: -3, belonging: 12, flag: 'xiao_wang_goodbye' },
        feedback: '你们在 Pret 见了。他瘦了一圈，眼睛是肿的。他说"我其实想了很多次想私聊你，但你看起来很忙。" 你说"别这样想 你一个学期一个学期前就可以的。" 他笑了，"下次了。"\n\n你目送他走出 Pret 的时候，发现自己也哭了。' },
      { label: '群里发"保重 一切顺利"', effect: { belonging: 4 },
        feedback: '小王回了一个流泪的表情。一周后群里他真的退群了。你看着"新生小王退出群聊"那行字，看了很久。' },
      { label: '不回复', effect: { belonging: -8 },
        feedback: '一周后小王退群了。半年后你才意识到，他可能就在等你那一句话。' },
    ],
  },
  {
    id: 'at_kaize_homeless',
    week: 19,
    askerId: 'kaize',
    title: '凯泽求救留宿',
    setup: '深夜 12 点。群里。',
    askerMsg: '@所有人 房东突然把我赶出来 说我转租 我没有 我现在在 Costa 24 小时店 谁能借宿一晚',
    choices: [
      { label: '"过来吧 我家沙发"', effect: { energy: -8, belonging: 15, wallet: -10, flag: 'kaize_friend' },
        feedback: '凯泽来了。两个 28 寸箱子，一个 Costa 杯。他在你沙发上睡了三天，第四天他找到了新地方。\n\n他临走时给你买了一袋吃的，还有一张手写卡片："这一辈子记着你。" 你把卡片夹在了书里。' },
      { label: '"我家也住了人 抱歉"', effect: { energy: -1, belonging: -2 },
        feedback: '上岸了的姐收留了他。一周后他在群里 @了上岸了的姐："姐 这辈子记着你。" 你没被 @。' },
      { label: '不回复', effect: { belonging: -8 },
        feedback: '半小时后狗哥说"过来 我宿舍不让住人 我跟你蹲一晚 Costa"。你想：原来你以为冷漠的人，没你冷漠。' },
    ],
  },
  {
    id: 'at_chunjie_huiguo',
    week: 18,
    askerId: 'lily',
    title: '春节群里 @你',
    setup: '大年三十。群里在抢红包。Lily @你。',
    askerMsg: '@你 你今年回国吗？我已经回了 三亚 [图]',
    choices: [
      { label: '"没回 在伦敦"', effect: { energy: -2, belonging: -3 },
        feedback: 'Lily："那今年不容易啊 多吃点。" 你看着"多吃点"三个字，发了五秒呆。' },
      { label: '"回了 [假图]"（撒了个小谎）', effect: { energy: -3, belonging: -5 },
        feedback: '你随便发了张去年回家时拍的照片。Lily："好棒哇～" 你心里是空的。' },
      { label: '"在伦敦 自己包饺子"', effect: { energy: 2, belonging: 5 },
        feedback: 'Lily："牛 我要是会包就好了。" 上岸了的姐："包饺子的人才是真的过年。"' },
    ],
  },
  {
    id: 'at_essay_help',
    week: 41,
    askerId: 'xiao_wang',
    title: '论文季求救',
    condition: ({ stats }) => stats.academic >= 50,
    setup: '论文季中段。',
    askerMsg: '@你 求救 methodology 那一章我完全卡住了 你那段写得真好 能给我看看吗',
    choices: [
      { label: '把自己的 methodology 部分发给 ta', effect: { energy: -3, belonging: 8, academic: -2 },
        feedback: 'ta 第二天回："你的写法启发了我 我重写了 谢谢"。你想：我的写法启发了别人。这是这一年里你听过最让人想哭的赞美之一。' },
      { label: '"不方便发 但可以聊聊思路"', effect: { energy: -5, belonging: 5 },
        feedback: '你和 ta 视频 1 小时。讲完之后 ta 说"豁然开朗"。你也豁然开朗——原来教别人是巩固自己最好的方法。' },
      { label: '"抱歉 还没写完"', effect: { belonging: -1 },
        feedback: 'ta 回"理解 加油"。你回到自己的论文。' },
    ],
  },
];

// ========================================
// 心理状态：梦境
// ========================================

const DREAMS = [
  {
    id: 'dream_pre_departure',
    title: '出国前最后一晚',
    body: '你梦回出国前那个晚上。爸爸坐在你的箱子旁，认真地检查你忘了什么。\n\n他抬头说："袜子带够了吗？充电器呢？多带几袋老干妈。"\n\n你说"我带了"。他点点头，没再说话。然后他走出房间，关门前回头看了你一眼。\n\n那个眼神你没忘记。但醒来的时候，你想：你忘记了。',
  },
  {
    id: 'dream_grandma',
    title: '奶奶的饺子',
    body: '你梦到奶奶在包饺子。她已经走了三年。\n\n她抬头看你，笑着说："回来了？吃饺子吧。" 她把一个饺子塞到你手里——还是你 8 岁时她最爱给你包的那种，皮厚馅多。\n\n你咬了一口。咸的。是泪。\n\n你哭着醒过来。',
  },
  {
    id: 'dream_school',
    title: '小学的操场',
    body: '你梦到小学的操场。下午 4 点的阳光斜照在跑道上。\n\n那个时候你 9 岁。你坐在台阶上等妈妈来接。\n\n你梦里也在等。梦里妈妈一直没来。',
  },
  {
    id: 'dream_lost_graduation',
    title: '找不到的礼堂',
    body: '你梦到自己穿着学袍。毕业典礼。但你怎么也找不到礼堂。\n\n你在 quad 里转了一圈又一圈。每个人都从你身边走过，朝同一个方向。但你看不见门。\n\n你急得快哭了。然后你想——为什么我急成这样？\n\n醒来你出了一身汗。',
  },
  {
    id: 'dream_silent_english',
    title: '说不出的英语',
    body: '你梦到自己在 tutorial 上。Whitmore 看着你："What do you think?"\n\n你张嘴。但你说不出来。任何一个词都说不出来。\n\n你 panic 了。教室里所有人盯着你。\n\n醒来你坐了起来。然后你大声说了一句："I think the argument is flawed."\n\n好。你能说。',
  },
  {
    id: 'dream_ex_wedding',
    title: '前任的婚礼',
    body: '你梦到一个你曾经喜欢的人结婚了。他/她穿着你不认识的衣服，站在你不认识的人旁边。\n\n你站在远远的角落，没有走近。\n\n醒来你查了 ta 的朋友圈——还是去年的最后一条。你松了一口气。然后你又愣了——为什么松一口气。',
  },
  {
    id: 'dream_tube_stuck',
    title: '困在两站之间',
    body: '你梦到 tube 停在两站之间。整车厢的人，包括你，都不说话。\n\n灯一明一灭。播报说"a moment please"。\n\n你看了看表。你已经在那里坐了 2 小时。但你不急。你只是看着窗外的黑暗。\n\n你醒来时想：我什么时候开始不急了。',
  },
  {
    id: 'dream_no_pickup',
    title: '没人来接的机场',
    body: '你梦到自己回国了。下了飞机。出关。走到接机口。\n\n大屏幕上没你的名字。爸妈不在。\n\n你站在那里，旁边的人一个个被接走。最后只剩你。\n\n你打电话给妈妈。她说："你明天才到啊。我现在在做饭。"\n\n你说"哦"。然后挂了。',
  },
  {
    id: 'dream_parents_old',
    title: '爸妈变老了',
    body: '你梦到爸妈。他们老了。比你出国那天老了 20 岁。\n\n你妈走路有点慢。你爸眼睛有点浑浊。\n\n他们看到你笑了，但没说话。\n\n你想说点什么。你想跑过去抱他们。但你的脚不动。\n\n你醒来。下午 3 点。你打开微信视频。你妈接了。她说："你今天怎么这么早起？"',
  },
  {
    id: 'dream_ten_years',
    title: '10 年后还不会的英文',
    body: '你梦到 10 年后的自己。还在伦敦。\n\n你走进 Pret。店员问："How are you, love?"\n\n你愣了一下。还是不知道该说 "Good" 还是 "Yeah cheers" 还是 "Not too bad"。\n\n10 年了。这个问题你还是答不好。\n\n醒来你笑了。然后又有点想哭。',
  },
];

// ========================================
// 心理状态：失眠独白
// ========================================

const INSOMNIA_THOUGHTS = [
  {
    id: 'insomnia_grade',
    title: '凌晨 3 点 · 反复刷分数',
    body: '凌晨 3:14。\n\n你已经第 11 次刷新成绩页面。还没出。\n\n你知道 12 小时之内不会出。但你还是刷。\n\n你想：如果挂了，怎么办。\n如果是 50 分呢。\n如果只是 60 分呢。爸妈会失望吗。\n\n你关了电脑。再打开。再关上。\n\n窗外开始下雨。',
  },
  {
    id: 'insomnia_money',
    title: '凌晨 3 点 · 算下个月预算',
    body: '凌晨 2:48。\n\n你打开 Excel。\n\n房租 £640。\n生活费目标 £400。\n手机 £15。\n地铁卡 £75。\n意外（坏掉的电脑维修，£150）。\n\n你还剩 £200 给自己零花。\n你算了三遍。\n\n第四遍你删掉了"零花"那一栏。',
  },
  {
    id: 'insomnia_xhs',
    title: '凌晨 3 点 · 小红书',
    body: '凌晨 3:32。\n\n你刷了 200 条小红书。\n\n"留学生月薪 1 万人民币不算什么"。\n"上岸花旗 base 香港"。\n"在伦敦遇到了我的他"。\n"我朋友圈里都是工签批了的"。\n\n你关掉手机。你的房间是黑的。\n\n你的人生不是别人写的标题。但今晚你忘了。',
  },
  {
    id: 'insomnia_call',
    title: '凌晨 3 点 · 想打电话又不敢',
    body: '凌晨 3:51。中国是上午 11 点。\n\n你妈现在应该在做午饭。\n\n你拿起手机。打开微信。\n手指在视频键上停了 30 秒。\n\n你想：她会问"你怎么这个点还不睡"。\n你想：她会担心。\n你想：我没什么事，就是想听她说话。\n\n你按了"返回"。\n你把手机关上。',
  },
  {
    id: 'insomnia_deadline',
    title: '凌晨 3 点 · 想起 deadline',
    body: '凌晨 4:02。\n\n你在床上翻来覆去。\n\n你想起：明天上午 12 点是 essay deadline。\n你以为是后天。\n\n你坐了起来。开了灯。打开电脑。\n\n8 小时。3000 字。还能干。\n\n你又想：人生大部分崩溃，都是从凌晨 4 点突然想起来什么开始的。',
  },
];

// ========================================
// 心理状态：思乡时刻
// ========================================

const NOSTALGIA_MOMENTS = [
  {
    id: 'nostalgia_redenvelope',
    trigger: 'spring_festival',
    title: '群里抢红包',
    body: '大年三十夜里 11 点（伦敦）。家族群里在抢红包。\n\n你点进去。"已被领完"。\n你刷新。"已被领完"。\n你刷新。"已被领完"。\n\n8 个红包，你一个都没抢到——网络延迟。\n\n你二舅发了一句："那边的孩子也不能落下啊。" 然后单独转给了你 ¥88。\n\n你看着屏幕。突然不知道为什么哭了。',
  },
  {
    id: 'nostalgia_moon',
    trigger: 'mid_autumn',
    title: '中秋的雾',
    body: '中秋。你的朋友圈全是月亮——清晰的、圆的、橘色的月亮。\n\n你打开窗。伦敦今天下雾。你看不见月亮。\n\n你给妈妈发："这边没月亮。"\n你妈秒回："妈这边的发给你。" 接着是一张她举着手机拍的月亮。手抖了，模糊的。\n\n但那是你 22 岁那一年看到过的最圆的月亮。',
  },
  {
    id: 'nostalgia_mom_birthday',
    trigger: 'mom_birthday',
    title: '忘了妈妈生日',
    body: '你刷朋友圈。看到你姑妈发"祝姐姐生日快乐 越活越年轻"。\n\n你愣了 3 秒。\n\n今天是你妈生日。你忘了。\n\n你打了一个电话过去。她接了，没说生日的事。她说："吃饭了吗？"\n\n你没敢提。挂了之后你给她发了 ¥1000 红包，备注"妈生日快乐 我忘了 对不起"。\n\n她回了三个字："傻孩子。"',
  },
  {
    id: 'nostalgia_wedding',
    trigger: 'classmate_wedding',
    title: '高中群发的婚礼照',
    body: '高中同学群弹出 99+。你点进去。\n\n班花发了 9 宫格婚礼照片。新郎是你认识的男生 / 你不认识的女生。\n\n你看了 30 秒。然后开始往上滑。\n\n3 年没消息的群，今天有 200 多条。你认识的每个人都在祝福。\n\n你没发任何东西。\n\n关掉群之后你坐在 flat 里很久。你想：他们的人生在按部就班地进行。我的呢？',
  },
  {
    id: 'nostalgia_song',
    trigger: 'random',
    title: '一首旧歌',
    body: '你在 Tesco 听到了一首歌。\n\n是 2018 年你高中毕业晚会上放过的那首。\n\n你站在饮料柜前 20 秒没动。\n\n后面的英国大叔说了一句"excuse me, love?"\n\n你说 sorry，让开。然后你买了一瓶水，付钱，走出 Tesco。\n\n你在街上又听完了那首歌一遍。然后才回家。',
  },
  {
    id: 'nostalgia_package',
    trigger: 'random',
    title: '家里的快递',
    body: '邮差送来一个箱子。妈妈寄的。\n\n你拆开。里面是 8 包老干妈、4 包榨菜、2 罐麦片、1 包卫龙、1 件毛衣（妈妈织的）、还有一封信。\n\n你打开信。第一行："冷不冷？"\n\n你读到第三行就读不下去了。\n\n你把毛衣穿上。它有点扎。但你穿了一整天没脱。',
  },
];

// ========================================
// 陌生人加好友后的专属事件
// 加完友后，第 X 周触发。每个陌生人 2 个事件
// ========================================

// ========================================
// 父母来伦敦线 - 5 章独立剧情
// 用 flag 推进，每章触发条件不同
// ========================================

const PARENTS_STORY = [
  {
    id: 'parents_1_offer',
    chapter: 1,
    title: '妈妈的提议',
    triggerWeek: 6,
    triggerType: 'after_call_home', // 在"给家里打电话"行动后触发
    requireFlag: null,
    body: '你和妈妈视频。她支吾了半天，最后说：\n\n"我和你爸商量了。我们想春节后来看看你。可以吗？"\n\n你愣了 3 秒。你妈一辈子没出过国。你爸 10 年前去过一次香港。\n\n她又说："不行也没事 妈知道你忙 我就是问问。"',
    choices: [
      { label: '"来！我特别想你们"', effect: { energy: 5, belonging: 18, flag: 'parents_coming' },
        feedback: '妈妈眼睛一下红了。"那行 那行。" 然后她转头跟你爸说："来 同意了。" 背景里你听到你爸"嗯"了一声。\n\n挂电话之后你坐在床边 5 分钟没动。原来这就是一种你想了很久但不敢说的事。' },
      { label: '"机票太贵了 你们别花这钱"', effect: { belonging: -5, flag: 'parents_declined' },
        feedback: '妈妈愣了一下："那 那好。妈也是想想。" 她笑了一下 但你看到她眼神变了。\n\n挂电话之后你站在窗前 想：我刚才到底怕什么？怕他们看到我活得不好？还是怕承认我想他们？' },
      { label: '"再说吧 等我忙完这阵"', effect: { belonging: 0 },
        feedback: '"行 行。" 妈妈点头。"反正我们也不急。"\n\n你知道她是什么意思。但你也知道 这种"再说"是会被遗忘的。' },
    ],
  },
  {
    id: 'parents_2_prep',
    chapter: 2,
    title: '"How are you, 标准吗"',
    triggerWeek: 17,
    requireFlag: 'parents_coming',
    body: '你们的下一次视频电话。你妈神秘兮兮地："我跟你爸学了一句英语 你听听标准吗。"\n\n她清清嗓子，然后认真地说：\n\n"how. are. you."\n\n每个词都重读得像在念古诗。\n\n你爸在背景里："你说太慢了 人家英国人都说快的。"\n\n你妈："我说慢点对方好懂。"\n\n他们俩为这个吵了 1 分钟。然后你妈又问你："标准吗？"',
    choices: [
      { label: '"特别标准 妈"', effect: { energy: 3, belonging: 15, flag: 'parents_prep_kind' },
        feedback: '你妈高兴："听到了吗 特别标准。我说我能学。" 你爸："那\'fine thank you and you\'呢" 你妈："这个我还在练" 你爸："那不还是不行吗"\n\n他们又吵了起来。你笑得肚子疼。' },
      { label: '"还行 但要快一点"', effect: { belonging: 8 },
        feedback: '你示范了一遍。你妈跟着念。她念了 6 遍才像。然后她说"妈不学这个了 反正有你"。' },
      { label: '"妈 你不用学这个"', effect: { belonging: 4 },
        feedback: '你妈愣了一下："为什么？" 你说"因为你儿子/女儿在那 不需要你说英语。" 她沉默了 3 秒，然后说"傻孩子"。' },
    ],
  },
  {
    id: 'parents_3_arrival',
    chapter: 3,
    title: 'Heathrow T3 接机',
    triggerWeek: 19,
    requireFlag: 'parents_coming',
    body: 'Heathrow T3。你比航班到达时间早到了 1 小时。\n\n你站在出口。你看到他们了。\n\n你妈推着一个比她还大的箱子。你爸拉着另一个。两个人都戴着口罩——你爸还戴了帽子。他们看起来又怯又兴奋，像两个第一次进城的小孩。\n\n你妈一眼看到你。她举起手——手里捧着一个袋子。\n\n是你 8 岁时最爱吃的那种饼干。她从国内一路抱过来的。\n\n她小跑过来。你爸跟在后面。',
    choices: [
      { label: '冲上去抱住妈妈', effect: { energy: 5, belonging: 25, flag: 'parents_arrived' },
        feedback: '你抱住她。她比一年前瘦了。她抱着你拍你的背："瘦了瘦了。"\n\n你爸站在旁边。他不会抱人。他就拍拍你的肩膀，连说三声："好。好。好。"\n\n然后他转过头去——你看到他偷偷擦了一下眼睛。' },
      { label: '挥手喊"爸 妈"', effect: { energy: 3, belonging: 18, flag: 'parents_arrived' },
        feedback: '你们在出口处尴尬地站了 3 秒，然后一起笑了。你妈："真是 出息了。" 你爸："瘦了瘦了。" 他们两个又同时说话。' },
    ],
  },
  {
    id: 'parents_4_tour',
    chapter: 4,
    title: '我的伦敦给你看',
    triggerWeek: 19,
    requireFlag: 'parents_arrived',
    body: '一周。你带他们看伦敦。\n\n大本钟前你爸坚持要你妈跟他合照——他举着 V 字手势。妈妈说"老了还做这个"，但她笑得像 18 岁。\n\n白金汉宫前妈妈："这真是女王住的地方？" 你说"现在是国王。" 她说："哦对哦 女王走了。可惜啊。"\n\n你带他们去 Mei\'s。Mei 姐看你爸妈一眼就喊："哎呀 叔叔阿姨！" 然后送了两道菜。你爸"这老板娘怎么这么热情"，你妈："肯定是常去的。" Mei 姐听到了 笑了。\n\n最难忘的是你带他们去你的大学。爸爸没说话。他走到主楼前，抚摸了一下学校的牌匾。',
    choices: [
      { label: '问爸爸："怎么了"', effect: { energy: -3, belonging: 28, flag: 'parents_uni' },
        feedback: '爸爸沉默了 5 秒。然后说：\n\n"我大学没毕业。"\n\n你愣住。你不知道。\n\n"我考上了。但你爷爷生病。我退学回去打工。" 他擦了一下眼睛 还是看着那块牌匾。"我看你能进这种学校 我心里...就是说不出。"\n\n你妈在旁边没说话。她也擦眼睛。\n\n你站在你爸旁边 也摸了一下那块牌匾。' },
      { label: '让他自己看一会', effect: { belonging: 15, flag: 'parents_uni' },
        feedback: '爸爸看了那块牌匾 5 分钟。然后他转过来，眼睛是红的，但他没说话。他只是拍了拍你的肩膀。\n\n后来你妈跟你说："你爸大学没毕业 你不知道吧。爷爷那时候病了。" 你才知道他刚才在想什么。' },
    ],
  },
  {
    id: 'parents_5_goodbye',
    chapter: 5,
    title: 'Heathrow T3 送别',
    triggerWeek: 20,
    requireFlag: 'parents_uni',
    body: 'Heathrow T3 安检口。\n\n妈妈塞给你一沓 £100 现金。"妈给你的。" 你不要。她硬塞。最后你妥协了。\n\n你爸忽然开口："这一年让你一个人。" 然后停了一下。"对不起。"\n\n你愣住。你爸这辈子没跟你说过对不起。\n\n他不再看你。他看着安检口的天花板。\n\n你妈推他："走了 飞机要起飞了。"\n\n他们走进安检通道。妈妈回头看了你一眼。你看到她在哭。\n\n然后他们消失在拐角。',
    choices: [
      { label: '在 Heathrow 站着不动', effect: { energy: -8, belonging: 35, flag: 'parents_visited' },
        feedback: '你站在 Heathrow T3 的玻璃墙前 20 分钟没动。你看着飞机起降。\n\n地铁上你哭了 30 分钟。一个英国老太太递给你一张纸巾，说"It\'ll be ok, dear"。你点头说 thank you。\n\n但你回到 flat 的时候——你想：原来这才是我留学的意义。\n\n不是文凭。不是 distinction。不是工签。\n\n是让他们看到我变成的人。是让我爸第一次跟我说"对不起"。是让我妈学会说"How are you"。\n\n这一年值了。' },
      { label: '逃出 Heathrow', effect: { energy: -10, belonging: 25, flag: 'parents_visited' },
        feedback: '你不敢看他们消失。你转身就走 几乎是逃。\n\n地铁上你戴上耳机假装睡觉。但你眼泪还是流下来。坐你旁边的一个印度大叔把他的纸巾整包给你。你点头 没说话。\n\n你回到 flat。屋子里还有他们的味道。' },
    ],
  },
];

const STRANGER_EVENTS = [
  // ===== 小李（传媒）=====
  {
    id: 'xl_vlog_help', strangerId: 'xiao_li', weeksAfter: 5,
    title: '小李来求拍摄帮忙',
    body: '小李群里 @你："学弟/学妹 救救命 我想做一个 Camden 美食 vlog 但我不会运镜 你能不能陪我拍一下午 请你吃 Camden 所有好吃的"',
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
        feedback: '阿强回："必须的。"\n\n半年后他真的把婚礼请柬发到了群里。三亚。机票他报销。你想这就是中国留学生圈——一切都荒诞，但情谊都是真的。' },
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
      { label: '去', effect: { energy: -3, wallet: 0, belonging: 15, flag: 'tt_offer_dinner' },
        feedback: '她带你去了 Aqua Shard 31 楼。窗外伦敦的灯像撒了一地。\n\n她说："我面试的时候紧张到哭。后来我想起你那次跟我朋友们说话的样子——你不会装。我学了你那一点。"\n\n你愣了。原来你也教过别人东西。' },
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
        feedback: '老周老婆 38 岁，温柔得过分。她做了一桌东北菜。她不停地夹菜给你："你比我们家儿子还瘦。"\n\n她小声说："谢谢你。他在这边一个人 没朋友。我每天担心他 但你来了之后他朋友圈又开始更新了。"\n\n你说不出话来。你只是低头吃了她做的酸菜炖排骨。' },
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
];

const LOCATIONS = [
  { id: 'flat', name: '公寓', en: 'Your Flat', emoji: '🏠', cost: 0, desc: '你的小窝。狭窄但安全。' },
  { id: 'uni', name: '大学', en: 'University', emoji: '🎓', cost: 0, desc: '主楼里永远有人在赶 deadline。' },
  { id: 'library', name: '图书馆', en: 'Library', emoji: '📚', cost: 0, desc: '24小时开放。Aditi 通常在 4 楼。' },
  { id: 'tesco', name: 'Tesco', en: 'Tesco Express', emoji: '🛒', cost: 0, desc: '基础生存。晚上有黄标。' },
  { id: 'mei', name: 'Mei\'s', en: '中餐馆 Lucky Star', emoji: '🍜', cost: 0, desc: '一个能让你想起家的地方。' },
  { id: 'pub', name: 'Pub', en: 'The Crown', emoji: '🍻', cost: 0, desc: '木头桌椅，谈话声，啤酒味。' },
  { id: 'park', name: 'Hyde Park', en: 'Hyde Park', emoji: '🌳', cost: 0, desc: '伦敦人遛狗的地方。' },
  { id: 'tate', name: 'Tate Modern', en: 'Tate Modern', emoji: '🎨', cost: 0, desc: '免费，并且暖气足。' },
  { id: 'camden', name: 'Camden', en: 'Camden Market', emoji: '🛍️', cost: 0, desc: '又脏又有意思的地方。' },
  { id: 'station', name: '火车站', en: 'King\'s Cross', emoji: '🚆', cost: 0, desc: '通往别处。' },
];

const TRAVEL_DESTINATIONS = [
  { id: 'edinburgh', name: '爱丁堡', cost: 60, days: 3, desc: '北方的石头城，威士忌的味道。',
    flag: 'eng_color' },
  { id: 'paris', name: '巴黎', cost: 120, days: 3, desc: '欧洲之星 2 小时。需要 £120。',
    flag: 'fr_color' },
  { id: 'amsterdam', name: '阿姆斯特丹', cost: 90, days: 3, desc: '运河和单车的城市。',
    flag: 'nl_color' },
  { id: 'rome', name: '罗马', cost: 180, days: 4, desc: '一座露天博物馆。',
    flag: 'it_color' },
  { id: 'home', name: '回国', cost: 800, days: 14, desc: '£800。只有寒假/复活节能去。',
    condition: (state) => { const w = getWeekInfo(state.week); return w.isHoliday; } },
];

// 旅行专属事件（每个城市有自己的事件池 + 专属 NPC + 明信片）
const TRAVEL_EVENTS = {
  edinburgh: [
    { id: 'arthurs_seat', title: 'Arthur\'s Seat 日出',
      body: '凌晨 5 点。你裹着毯子，在零下 3 度的山顶上等日出。\n\n云破开的那一刻，整个 Edinburgh 在你脚下亮起来——古城的塔尖像一片黑色的森林。',
      effect: { energy: -8, belonging: 12, academic: 0 },
      feedback: '你坐在山顶 2 小时没说话。下山的时候双腿发抖。但有些瞬间，你这一辈子都不会忘。',
      postcard: '🏰 我在世界尽头看了一次日出' },
    { id: 'old_tom', title: '威士忌酒馆',
      body: 'Royal Mile 角落里的一家小酒馆。Old Tom 已经在这里 40 年了。他给你倒了一杯免费的 Laphroaig。\n\n"You look tired, lass/lad. Where you from?" 你说了。他点点头。"Aye. Been there once. Long time ago."',
      effect: { energy: 5, wallet: -8, belonging: 10 },
      feedback: 'Old Tom 讲了他 1971 年去香港当海员的故事。你听了 1 小时。临走时他拍拍你肩膀："Come back next time, eh?"',
      postcard: '🥃 一杯陌生人的威士忌' },
    { id: 'piper', title: 'Royal Mile 的风笛',
      body: '一个穿苏格兰裙的中年男人在街角吹风笛。曲子是 *Auld Lang Syne*——你大学毕业典礼上听过的旋律。',
      effect: { energy: -3, belonging: 8 },
      feedback: '你在他帽子里放了 £2。他点头，没停下吹奏。你站在那里听完了整首。然后转身就哭了。原来你已经那么久没哭了。',
      postcard: '🎶 街头的 Auld Lang Syne' },
    { id: 'storm', title: '暴风雨困在青旅',
      body: 'Storm Brendan。整个爱丁堡下了 24 小时大雨。你被困在 hostel 客厅。一个澳洲背包客掏出一瓶威士忌："Help yourself, mate."',
      effect: { energy: 8, wallet: 0, belonging: 12 },
      feedback: '你们 6 个人围着小桌玩牌。一个德国女孩唱了一首她奶奶教她的歌。一个美国男孩讲了他逃离前妻的故事。你讲了你妈给你打视频电话的事。\n\n暴风雨第二天天晴时你们都有点舍不得说再见。',
      postcard: '🌧️ 6 个陌生人和一瓶威士忌' },
    { id: 'glencoe', title: 'Glencoe 山区',
      body: '£40 day trip 巴士。开 3 小时进入苏格兰高地。司机是个 70 岁的老头，全程用浓重口音讲苏格兰历史故事。',
      effect: { energy: -5, wallet: -40, belonging: 15 },
      feedback: 'Glencoe 山谷在云里时隐时现。你站在风里，觉得自己变得很小。但不是糟糕的小——是那种"原来世界这么大"的小。',
      postcard: '⛰️ 苏格兰高地的风' },
  ],

  paris: [
    { id: 'seine_painter', title: '塞纳河边的画家',
      body: '一个老头坐在河边画桥。你站在他后面 30 分钟。他画完了，转身看你："Vous voulez? £40."',
      effect: { energy: 0, wallet: -40, belonging: 8 },
      feedback: '你买了那幅画。他在背面用铅笔写："Pour mon ami chinois. Pierre, 2024." 你把它带回伦敦，挂在 flat 的床头。',
      postcard: '🎨 一个老画家的桥' },
    { id: 'pere_lachaise', title: 'Père Lachaise 公墓',
      body: '雨后的午后。你按地图找王尔德的墓——一个长着翅膀的天使雕像，上面布满了红唇印。',
      effect: { energy: -3, belonging: 10 },
      feedback: '你也在墓上轻轻吻了一下。然后又找了肖邦的墓，给他放了一支花。你一个人在公墓里走了 3 小时。这是你来欧洲后最安静的一个下午。',
      postcard: '🌹 王尔德的红唇印' },
    { id: 'phone_stolen', title: '被偷手机',
      body: '你在 Métro 14 号线。一群少年挤过来。你下车后摸口袋——空的。',
      effect: { energy: -15, wallet: -150, belonging: -5 },
      feedback: '你花 2 天补办了一个新手机。那 £150 是你预算外的支出。\n\n但你也学到了一课：欧洲不是哈利波特小说。出门把手机放最里层口袋。',
      postcard: '📱 巴黎初体验' },
    { id: 'sophie_cafe', title: 'Sophie 的咖啡店',
      body: '小巷子里的咖啡店。店员是个 25 岁的女生，看到你犹豫的样子用中文说了一句："不知道要点什么吗？"\n\n你愣了。她笑了："我在巴黎大学读中文。叫 Sophie。"',
      effect: { energy: 5, wallet: -6, belonging: 12 },
      feedback: 'Sophie 推荐了 *café gourmand*——一杯咖啡配 4 种小甜点。你坐了 1 小时。她下班路过你旁边："如果你下次再来巴黎，加我微信。"\n\n她真的有微信。她的网名是"在巴黎想吃面条的 Sophie"。',
      postcard: '☕ 在巴黎遇到一个会中文的女孩' },
    { id: 'louvre_lost', title: '卢浮宫迷路',
      body: '你买了 €17 的门票。计划 3 小时看完所有重要藏品。结果：你在埃及厅迷路了 1.5 小时。',
      effect: { energy: -10, wallet: -17, belonging: 5 },
      feedback: '你只看到了 *Mona Lisa*（被人挤）和 *Venus de Milo*。你出来时觉得自己是个文化文盲。但你也想：那么多艺术，本来就不是 3 小时能看完的。',
      postcard: '🖼️ 在卢浮宫迷路的下午' },
    { id: 'montmartre', title: '蒙马特的台阶',
      body: '你坐在 Sacré-Cœur 前的台阶上，吃 €3 的 baguette 配 brie 奶酪。\n\n夕阳把整个巴黎染成橘色。',
      effect: { energy: 8, wallet: -3, belonging: 15 },
      feedback: '一个街头吉他手开始弹 *La Vie en Rose*。一对老夫妻在你旁边跳起舞来。你录了一段视频发给妈妈。她回："看着真好。"\n\n你想，是的。看着真好。',
      postcard: '🎸 La Vie en Rose 的夕阳' },
  ],

  amsterdam: [
    { id: 'canal_bike', title: '运河单车',
      body: '你租了一辆 €15/天的单车。10 分钟后你差点掉进运河。一个荷兰大叔从后面冲你喊："First time, eh?"',
      effect: { energy: -3, wallet: -15, belonging: 10 },
      feedback: '他骑过来教你怎么过桥。"In Amsterdam, bikes are king. You learn or you die." 然后他笑着骑走了。\n\n第二天你已经能用一只手骑车，另一只手吃 stroopwafel。',
      postcard: '🚲 我学会了在阿姆斯特丹骑车' },
    { id: 'anne_frank', title: 'Anne Frank 故居',
      body: '排了 1 小时队。然后你走进了那个隐藏的密室。\n\n窗户被木板封死。一张她写日记的小桌子。',
      effect: { energy: -5, wallet: -16, belonging: 8 },
      feedback: '你在一个房间里站了 10 分钟没说话。出来时阳光太亮，你眯着眼睛走在运河边。你想：我抱怨的所有事情，跟那扇被封死的窗户比，都不算什么。',
      postcard: '📖 一个女孩的窗' },
    { id: 'coffeeshop', title: '"Coffeeshop"',
      body: '你好奇地走进了一家 "coffeeshop"——你知道在阿姆斯特丹这意味着什么。',
      effect: { energy: -3, wallet: -10, belonging: 3 },
      feedback: '你只点了一杯咖啡，没买别的。隔壁桌的德国大学生看你的眼神就像看一个 confused 的小孩。\n\n你喝完咖啡逃走了。但你回伦敦后这个故事讲了一年。',
      postcard: '🍵 "我只是喝了杯咖啡"' },
    { id: 'maja_hostel', title: 'Maja 的故事',
      body: 'Hostel 八人间。你的下铺是 Maja，一个 28 岁的波兰女生。她正在做"30 岁前去 30 个国家"的挑战，阿姆斯特丹是第 27 个。',
      effect: { energy: 5, belonging: 12 },
      feedback: '你们聊到凌晨 2 点。Maja 说她妈不理解她。"她说我应该结婚。我说我想去摩洛哥。" 你说你妈也不理解你。\n\n你们交换了 Instagram。三年后她还会偶尔给你发她在某个国家的照片。',
      postcard: '👋 Maja 的第 27 个国家' },
    { id: 'vondelpark', title: 'Vondelpark 野餐',
      body: '阳光好得不像北欧。你买了一袋面包和一块 gouda 奶酪，坐在 Vondelpark 草地上。',
      effect: { energy: 12, wallet: -8, belonging: 10 },
      feedback: '一只松鼠跑到你脚边。一个荷兰小孩走过来问："Can I pet your... oh you don\'t have a dog." 然后他失望地走开了。\n\n你笑了一下午。',
      postcard: '🌳 阳光好得不像北欧' },
  ],

  rome: [
    { id: 'colosseum', title: '斗兽场前',
      body: '你买了 €18 的票。走进斗兽场的那一刻，你愣住了。\n\n你想起 8 岁那年。你爸指着电视里的画面说："等你大了，爸爸带你去看罗马。" 他没去过。',
      effect: { energy: -3, wallet: -18, belonging: 12, flag: 'rome_colosseum' },
      feedback: '你在斗兽场的最高一层站了 1 小时。然后你给爸爸打了个电话。"爸 我替你看了。" 他在那头沉默了好久。然后说："好。" 就一个字。\n\n你们俩都没说话，但你听到他在哭。',
      postcard: '🏛️ 替我爸看了罗马' },
    { id: 'vatican', title: '梵蒂冈震撼',
      body: '西斯廷教堂。米开朗基罗的《创世纪》。你抬头 20 分钟，脖子都酸了。',
      effect: { energy: -5, wallet: -20, belonging: 10 },
      feedback: '一个意大利老太太走过来，用手指了指天顶："Bello, eh?" 你点头。她笑了，往前走了。\n\n你发现你不需要语言来理解美。',
      postcard: '🎨 抬头看了 20 分钟天' },
    { id: 'spanish_steps', title: '西班牙台阶',
      body: '你来到 Roman Holiday 里的西班牙台阶。结果——它正在维修。蓝色的塑料布盖了一半。',
      effect: { energy: -3, belonging: -3 },
      feedback: '你坐在台阶半边能坐的地方。一个游客模仿奥黛丽赫本的姿势拍照，但背景是塑料布。你笑了。\n\n人生大部分时候就是这样——你期待的画面总有点偏差，但你还是要去。',
      postcard: '🪜 维修中的西班牙台阶' },
    { id: 'carbonara', title: '一辈子最好的 carbonara',
      body: 'Trastevere 区，一家老奶奶开的小馆子。Carbonara €12。',
      effect: { energy: 12, wallet: -15, belonging: 8 },
      feedback: '第一口你愣住。第二口你想哭。第三口你已经在想"我今天能不能再来一份"。\n\n老奶奶看你的表情，笑着说了一句意大利语。你不懂，但你点头。',
      postcard: '🍝 一辈子最好的一口' },
    { id: 'roma_gypsy', title: '罗马的吉普赛人',
      body: 'Termini 火车站。一群吉普赛小孩围住你，假装要给你戴花。你认出这是经典骗术——他们想偷你的钱包。',
      effect: { energy: -8, belonging: -2 },
      feedback: '你紧紧捂住口袋，大声说"NO"。他们跑了。你逃出火车站时手在抖。\n\n但你也松了一口气：你不再是那个 9 月刚来欧洲的、什么都不懂的自己了。',
      postcard: '⚠️ 在罗马捍卫了我的钱包' },
    { id: 'church_quiet', title: '一座小教堂',
      body: '你不信教。但你走进了一座小教堂避雨。\n\n里面没有人。蜡烛在烧。天花板很高。',
      effect: { energy: 8, belonging: 12 },
      feedback: '你坐在最后一排长椅上，听雨声敲打彩色玻璃窗。\n\n你不知道自己坐了多久。出来的时候雨已经停了。但你想，有些时候人需要的就是一个安静的、可以坐下来的地方。',
      postcard: '⛪ 一个非教徒的下午' },
  ],
};

// ========================================
// NPC 关系网
// ========================================

const NPC_NETWORK_EVENTS = [
  // ===== 王凯 - Mei 姐 (华人圈) =====
  {
    id: 'wk_introduce_mei',
    title: '王凯帮你引荐 Mei 姐',
    body: '王凯说："哥们 你天天吃 Tesco 也不是个事。我带你去吃个饭。"\n\n你们走进 Mei\'s。王凯一进门就用闽南话和老板娘打招呼。她看了你一眼："你朋友？"\n\n王凯："学弟/学妹 第一年的。"\n\nMei 姐："哎呀真是，进来进来。"',
    location: 'mei',
    condition: ({ npcRel }) => (npcRel.wangkai || 0) >= 4 && (npcRel.mei || 0) <= 1,
    auto: true,
    choices: [
      { label: '认真感谢两个人', effect: { energy: 3, belonging: 8, npc: { wangkai: 2, mei: 3 } },
        feedback: 'Mei 姐多送了你们一道炒青菜。她跟王凯说"这孩子看起来老实"。王凯小声跟你说"Mei 姐人最好了"。你这一顿吃得心里暖暖的。' },
    ],
  },
  {
    id: 'mei_about_wk',
    title: 'Mei 姐说起王凯',
    body: '中餐馆只剩你和 Mei 姐。她擦着桌子，突然说："你那个王学长啊，去年和女朋友分手了，挺可怜的。"\n\n你愣了。你不知道。',
    location: 'mei',
    condition: ({ npcRel }) => (npcRel.wangkai || 0) >= 5 && (npcRel.mei || 0) >= 5,
    choices: [
      { label: '"啊 我都不知道"', effect: { energy: -2, belonging: 4, npc: { mei: 1 } },
        feedback: 'Mei 姐说："他不会跟你说的。男孩子嘛。" 然后她叹了口气。"你要多照顾他点。"\n\n你回去之后看了一晚上王凯的朋友圈。原来去年圣诞他发的"独自一人"不是开玩笑。' },
      { label: '"他没跟我说过"', effect: { belonging: 2, npc: { mei: 0, wangkai: -1 } },
        feedback: 'Mei 姐看了你一眼："那你是他什么朋友？" 这句话有点扎人。\n\n你回去之后给王凯发了"哥 周末一起吃饭吗"。他半天才回："行 你请客啊。"' },
    ],
  },
  {
    id: 'wk_mei_gossip',
    title: '王凯吐槽 Mei 姐',
    body: '王凯一边喝奶茶一边说："Mei 姐昨天又跟我说你的事。她说\'王凯 你别带坏那个孩子\' 哥们你说我是不是坏人。"',
    location: 'camden',
    condition: ({ npcRel }) => (npcRel.wangkai || 0) >= 6 && (npcRel.mei || 0) >= 5,
    choices: [
      { label: '笑着说"她是关心我"', effect: { energy: 3, belonging: 6, npc: { wangkai: 1, mei: 1 } },
        feedback: '王凯笑了："是是是 Mei 姐人最好了。" 然后他叹气："就是我妈不在伦敦，她有点像我妈。" 你愣了一下。原来王凯也有他需要的人。' },
    ],
  },

  // ===== Sarah - Whitmore (学术圈) =====
  {
    id: 'sarah_about_whitmore',
    title: 'Sarah 转述 Whitmore',
    body: 'Sarah 在咖啡店突然说："Oh by the way—Whitmore mentioned you in supervision yesterday. He said you ask the most interesting questions in tutorial."\n\n你愣住。',
    location: 'pub',
    condition: ({ npcRel }) => (npcRel.sarah || 0) >= 5 && (npcRel.whitmore || 0) >= 3,
    choices: [
      { label: '"Really?? I had no idea"', effect: { energy: 8, belonging: 10, academic: 3, npc: { sarah: 1 } },
        feedback: 'Sarah 笑了："He doesn\'t say that about anyone. Trust me." 你回家路上一直在笑。原来你说的话，他真的有听。' },
      { label: '"He\'s just being polite"', effect: { energy: -3, belonging: -5, npc: { sarah: -1 } },
        feedback: 'Sarah 摇头："Trust me, Whitmore is never \'just polite\'." 但你不愿意接受。某种自我保护——如果不相信，就不会失望。' },
    ],
  },
  {
    id: 'whitmore_about_sarah',
    title: 'Whitmore 提起 Sarah',
    body: 'Office hours 结束。Whitmore 一边收拾文件一边说："Sarah tells me you two have been studying together. Good. She\'s a sharp one. You both think differently—that\'s how good ideas happen."',
    location: 'uni',
    condition: ({ npcRel }) => (npcRel.sarah || 0) >= 4 && (npcRel.whitmore || 0) >= 5,
    auto: true,
    choices: [
      { label: '"她帮了我很多"', effect: { energy: 3, academic: 4, belonging: 6, npc: { sarah: 1, whitmore: 1 } },
        feedback: 'Whitmore 点头："Good people are hard to find. Don\'t lose her." 这是你听过他最不"教授"的一句话。' },
    ],
  },

  // ===== Whitmore - Aditi (学术圈) =====
  {
    id: 'whitmore_about_aditi',
    title: 'Whitmore 谈到 Aditi',
    body: '你和 Whitmore 在走廊里走。他突然说："Your friend Aditi—she\'s working too hard. I see her in the library at midnight. Would you... talk to her?"',
    location: 'uni',
    condition: ({ npcRel }) => (npcRel.aditi || 0) >= 4 && (npcRel.whitmore || 0) >= 5,
    choices: [
      { label: '"我会的 教授"', effect: { energy: -3, belonging: 8, npc: { whitmore: 2, aditi: 2 } },
        feedback: '你那晚专门去图书馆找 Aditi。她抬头看到你愣了一下："How did you know I was here?"\n\n你说："Whitmore 让我来的。" 她哭了。她说没想到老师注意到她了。' },
      { label: '"她自己有自己的节奏"', effect: { belonging: -2, npc: { whitmore: -1 } },
        feedback: 'Whitmore 看了你一眼："Hmm." 那个 "Hmm" 持续在你耳边响了一周。' },
    ],
  },

  // ===== Sarah - Aditi (同班但不熟) =====
  {
    id: 'sarah_about_aditi',
    title: 'Sarah 私下问起 Aditi',
    body: 'Sarah 一边喝 G&T 一边说："Hey, you\'re close with Aditi, right? Is she okay? She always looks... exhausted."',
    location: 'pub',
    condition: ({ npcRel }) => (npcRel.sarah || 0) >= 5 && (npcRel.aditi || 0) >= 5,
    choices: [
      { label: '简单说"她最近不容易"', effect: { belonging: 4, npc: { sarah: 1, aditi: -1 } },
        feedback: 'Sarah 点头："Should I... reach out?" 你不知道该说什么。然后你说："Maybe a text would mean a lot." 第二天 Aditi 给你发"Sarah just texted me. That was nice"。' },
      { label: '"这是她的私事 不便说"', effect: { belonging: 6, npc: { sarah: 0, aditi: 3 } },
        feedback: 'Sarah 点头："Of course. Sorry." 你保护了 Aditi。她不知道，但你知道。' },
    ],
  },
  {
    id: 'three_lunch',
    title: '三人午餐',
    body: '你提议 Sarah 和 Aditi 一起吃午餐。她们以前没真正说过话。\n\n气氛一开始有点尴尬。Sarah 太外向，Aditi 太安静。',
    location: 'uni',
    condition: ({ npcRel }) => (npcRel.sarah || 0) >= 6 && (npcRel.aditi || 0) >= 6,
    choices: [
      { label: '主动当桥梁，让她们都自在', effect: { energy: -8, belonging: 15, npc: { sarah: 2, aditi: 2 } },
        feedback: '半小时后她们已经在讨论各自国家的婚礼传统。1 小时后 Sarah 大笑出声，Aditi 也罕见地放声笑。\n\n离开时 Aditi 跟你说："I\'ve never had two friends from completely different worlds. Thank you." 你愣了一下。原来朋友圈是可以建造的。' },
      { label: '让她们自己处理 不插嘴', effect: { energy: -5, belonging: 5 },
        feedback: '她们尴尬地聊完了 30 分钟然后各自走了。Aditi 后来跟你说"Sarah seems nice"，Sarah 跟你说"Aditi is... interesting"。但你能感觉到，她们不会再约第二次了。' },
    ],
  },

  // ===== 跨圈 (王凯 vs Sarah) =====
  {
    id: 'wk_meets_sarah',
    title: '王凯遇到 Sarah',
    body: '你和 Sarah 在 Pub。王凯刚好路过来打招呼：「哥们 这位是？」你介绍。\n\nSarah 用 BBC 口音的英语说"Lovely to meet you"。王凯也用英语回："Yeah... cool, cool."\n\n气氛凝固了 5 秒。',
    location: 'pub',
    condition: ({ npcRel }) => (npcRel.wangkai || 0) >= 6 && (npcRel.sarah || 0) >= 6,
    choices: [
      { label: '帮忙打圆场', effect: { energy: -5, belonging: 8, npc: { wangkai: 1, sarah: 1 } },
        feedback: '王凯走后 Sarah 说："He seems... cool." 第二天王凯给你发微信："哥们你那个金发朋友 行 你混得不错。" 你哭笑不得。两个世界第一次碰头。' },
    ],
  },
];


const NPCS = {
  sarah: {
    id: 'sarah', name: 'Sarah', cn: '莎拉', avatar: 'S', color: '#d4a574',
    role: '英国本地同学',
    bio: '金发，喜欢喝 G&T。本科直升研究生。偶尔会问你一些"傻"问题。',
    locations: ['uni', 'pub', 'library'],
  },
  wangkai: {
    id: 'wangkai', name: '王凯', cn: '王凯', avatar: '凯', color: '#c4615a',
    role: '中国学长',
    bio: 'PhD 第二年，消息灵通，会带你薅羊毛。',
    locations: ['mei', 'uni', 'camden'],
  },
  aditi: {
    id: 'aditi', name: 'Aditi', cn: '阿迪缇', avatar: 'A', color: '#a87fb8',
    role: '印度同学',
    bio: '每天图书馆最后一个走。她爸爸最近生病了。',
    locations: ['library', 'uni'],
  },
  whitmore: {
    id: 'whitmore', name: 'Prof. Whitmore', cn: '惠特摩尔教授', avatar: 'W', color: '#7a8a6a',
    role: '你的导师',
    bio: '60多岁，永远穿花呢西装，话里有话。',
    locations: ['uni'],
  },
  mei: {
    id: 'mei', name: 'Mei', cn: 'Mei 姐', avatar: '梅', color: '#b85070',
    role: '中餐馆老板娘',
    bio: '福建人，30年前来的伦敦。骂你的时候是真心疼你。',
    locations: ['mei'],
  },
};

// ========================================
// 剧情线（多步任务）
// ========================================

const STORYLINES = {
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
        trigger: { rel: 6, location: 'camden' },
        title_full: 'Camden 的咖啡',
        body: '王凯约你在 Camden 一家奶茶店见面。他说："我想搞个事情。Camden 这边一杯奶茶卖 £6，国内成本 5 块钱。我有个表哥能搞货源。我俩合伙开个外卖店，怎么样？"',
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
};

// ========================================
// 地点事件（按地点+概率出现）
// ========================================

const LOCATION_EVENTS = {
  tesco: [
    { id: 'yellow_label', title: '黄标抢购', body: '晚上 9 点。Tesco 员工推着小车出来。你和另外三个亚洲面孔同时盯着冷柜。',
      minigame: 'yellow_grab', minWeek: 1 },
    { id: 'tesco_quiet', title: '空旷的超市', body: '下午 3 点的 Tesco。空荡荡。你买了一盒草莓和一袋面包。',
      effect: { wallet: -8, energy: 4 }, minWeek: 1, repeatable: true },
  ],
  pub: [
    { id: 'pub_overheard', title: '吧台听到的话', body: '你听到旁边几个人在说"those Chinese students always..."。你听不全后面的话。',
      choices: [
        { label: '凑近听清楚', effect: { energy: -10, belonging: -8 },
          feedback: '"...always study so hard, makes me feel lazy." 你愣了一下。原来不是你想的那样。但你也没法松口气，因为你已经预设了最坏的情况。' },
        { label: '走开', effect: { energy: -5, belonging: -3 },
          feedback: '你换了个位置。一整晚你都在想他们到底说了什么。' },
      ], minWeek: 4 },
  ],
  park: [
    { id: 'park_dog', title: '一只跑过来的狗', body: '一只 Golden Retriever 突然跑到你脚边，摇尾巴。它的主人在远处喊 "Biscuit! Sorry!"',
      effect: { energy: 8, belonging: 5 },
      feedback: '你蹲下来摸了它。主人跑过来道歉，你说 "He\'s lovely!" 这是你这周说过的最真心的英文。', minWeek: 1, repeatable: true },
    { id: 'park_jog', title: '晨跑的人', body: '你在 Hyde Park 散步。一个跑步的中年男人对你说 "Lovely morning!" 然后跑走了。',
      effect: { energy: 5, belonging: 3 },
      feedback: '你愣了一下。然后笑了。Lovely morning. 是的，今天确实是。', minWeek: 2, repeatable: true },
  ],
  tate: [
    { id: 'tate_painting', title: '一幅画前', body: 'Rothko 的红色色块。你在它前面站了 20 分钟。',
      effect: { energy: 6, belonging: 2 },
      feedback: '一个中年女士走过来站在你旁边。她说 "It makes me cry every time." 你点头。她离开了。你又站了 10 分钟。', minWeek: 3 },
  ],
  library: [
    { id: 'lib_late', title: '凌晨的图书馆', body: '凌晨 2 点。整个 4 楼只有你和一个戴耳机的女生（Aditi）。',
      effect: { academic: 6, energy: -8, belonging: 2 },
      feedback: '你们一直没说话。但你们都知道彼此在这里。这就够了。', minWeek: 4, repeatable: true },
  ],
  station: [
    { id: 'station_choose', title: '选择目的地', body: 'King\'s Cross 站台。屏幕上滚动着各种地名。',
      isTravel: true, minWeek: 6 },
  ],
};

// ========================================
// 迷你游戏
// ========================================

// 抢黄标：在3秒内点中正确的商品
const YELLOW_LABEL_ITEMS = [
  { name: '寿司', emoji: '🍣', isYellow: true, price: 1.5 },
  { name: '三明治', emoji: '🥪', isYellow: true, price: 2 },
  { name: '苹果', emoji: '🍎', isYellow: false, price: 3 },
  { name: '面包', emoji: '🍞', isYellow: true, price: 1 },
  { name: '牛奶', emoji: '🥛', isYellow: false, price: 2.5 },
  { name: '可乐', emoji: '🥤', isYellow: false, price: 2 },
];

// 考试题
const EXAM_QUESTIONS = [
  {
    q: 'Which of these is a key feature of post-structuralist theory?',
    options: ['Fixed meanings', 'Decentering of subject', 'Empirical verification', 'Linear narrative'],
    correct: 1,
  },
  {
    q: 'In academic writing, "ergo" is best translated as:',
    options: ['However', 'Therefore', 'Although', 'Despite'],
    correct: 1,
  },
  {
    q: 'The Harvard referencing style requires:',
    options: ['Footnotes only', 'Author-date in text', 'No bibliography', 'Numerical citations'],
    correct: 1,
  },
  {
    q: 'A "tutorial" in UK universities typically refers to:',
    options: ['Online video', 'Small group discussion', 'Lecture hall class', 'Lab session'],
    correct: 1,
  },
  {
    q: 'What does "ibid." mean in citations?',
    options: ['In another book', 'In the same source', 'According to', 'Compare with'],
    correct: 1,
  },
];

// ========================================
// 假期事件
// ========================================

const HOLIDAY_EVENTS = {
  xmas: [
    {
      id: 'xmas_first_morning',
      title: '12月23号清晨',
      body: '宿舍楼空了。隔壁 Tom 凌晨 5 点就出门了，家在 Manchester。Mei 姐的店关门 4 天。Tesco 缩短营业时间。\n\n你坐在床上，看着窗外灰白的天。',
      isAuto: true,
    },
    {
      id: 'xmas_alone',
      title: '一个人的圣诞',
      body: '12月25日。整个伦敦像被按了静音键。地铁停运。街上没有人。',
      choices: [
        { label: '看一整天的剧', effect: { energy: 5, belonging: -8, academic: -2 },
          feedback: '你看完了一整季 The Crown。最后一集结束的时候，外面已经天黑了。你不知道现在是几点。' },
        { label: '出门走一走', effect: { energy: -5, belonging: 4 },
          feedback: '你沿着泰晤士河走了 2 小时。一个人都没有。但路灯下的雪粒在飞。这一刻很安静，很安静。' },
        { label: '给爸妈打三小时电话', effect: { energy: -3, belonging: 18 },
          feedback: '妈妈给你看年夜饭。爸爸难得地开了视频。你哥的孩子叫了一声"小姨/小姨夫"。你哭了，他们以为是网卡。' },
      ],
    },
  ],
  easter: [
    {
      id: 'easter_spring',
      title: '伦敦的春天',
      body: '4月初。海德公园的水仙开了。Pret 的橱窗里出现了"Hot Cross Buns"。你换下了冬天的大衣。\n\n这是你第一次看到伦敦的另一面。',
      isAuto: true,
    },
  ],
};

const HOLIDAY_CHOICES_XMAS = [
  { id: 'stay_alone', label: '🏠 留在伦敦，一个人过', desc: '安静、省钱、可能很孤独',
    effect: { energy: 5, wallet: -50, belonging: -15, academic: 5 },
    feedback: '三周里你看了 8 部电影、读了 3 本书、写完了下学期的预习。你瘦了 2 公斤。但你也强壮了一些——不是身体，是别的什么。' },
  { id: 'stay_friends', label: '🥟 留下来，跟其他留学生过', desc: '一起做饭、看春晚、不孤独',
    effect: { energy: 8, wallet: -100, belonging: 18, academic: 0 },
    feedback: '你们五个人挤在 Aditi 的小公寓。她做了咖喱，你做了西红柿炒蛋，王凯带了茅台。新年钟声响的时候你们都在大笑。这是你最难忘的一个圣诞。' },
  { id: 'go_paris', label: '🗼 飞巴黎', desc: '£120，3天，欧洲之星',
    effect: { energy: 8, wallet: -120, belonging: 12, academic: -3 },
    feedback: '塞纳河边，你拍了无数张照片。一个法国老人对你说了一句你听不懂的话，然后笑了笑走开。回程的欧洲之星上你睡着了。醒来已经在伦敦。' },
  { id: 'go_edinburgh', label: '🏰 飞爱丁堡', desc: '£60，3天，看霍格沃茨原型',
    effect: { energy: 6, wallet: -60, belonging: 10, academic: 0 },
    feedback: '你住在 Old Town 的青旅，凌晨爬上 Arthur\'s Seat 看日出。冷得手都发抖。但那个瞬间，你觉得自己不是在伦敦留学，而是在世界上活着。' },
  { id: 'go_rome', label: '🇮🇹 飞罗马', desc: '£180，4天，奢侈但值得',
    effect: { energy: 10, wallet: -180, belonging: 14, academic: -3 },
    feedback: '你站在斗兽场前流泪。不是因为感动——是因为你想起小时候你爸说"等你大了，我带你去看罗马"。他没去过。但你来了。' },
  { id: 'go_home', label: '✈️ 回国 14 天', desc: '£800，回家陪爸妈',
    effect: { energy: 25, wallet: -800, belonging: 30, academic: -5 },
    feedback: '你在机场看到爸妈的瞬间哭了。妈妈瘦了，爸爸的头发更白了。你住了 14 天，吃了 14 顿不重样的饭。回伦敦的飞机上，你看着舷窗外的云，第一次清楚地知道——你来留学不是逃避家，是为了知道家有多重要。' },
  { id: 'work_xmas', label: '💼 在 Mei 姐店里打工', desc: '+£600，但很累',
    effect: { energy: -20, wallet: 600, belonging: 6 },
    feedback: '中餐馆圣诞照常营业，全是落单的中国人。你 3 周端了无数个盘子。Mei 姐塞给你 £600 现金。"过年好好吃顿饭啊。"' },
];

const HOLIDAY_CHOICES_EASTER = [
  { id: 'easter_revise', label: '📚 全力复习准备期末', desc: '+学业，放弃假期',
    effect: { energy: -25, academic: 25, belonging: -10 },
    feedback: '你 4 周泡在图书馆。出来的时候发现已经春天了——你错过了整个樱花季。但你的笔记厚得像本书。' },
  { id: 'easter_eurorail', label: '🚆 欧铁通票一路玩', desc: '£400，去 5 个城市',
    effect: { energy: 15, wallet: -400, belonging: 25, academic: -8 },
    feedback: '阿姆斯特丹→柏林→布拉格→维也纳→布达佩斯。25 天。32 张照片。3 个新的故事。你回伦敦的时候，发现伦敦看起来好小。' },
  { id: 'easter_work', label: '💼 全职打工', desc: '4 周赚 +£1200',
    effect: { energy: -25, wallet: 1200, belonging: 0 },
    feedback: '你在中餐馆和奶茶店之间切换。4 周后你瘦了 4 公斤，但银行卡多了 £1200。你给爸妈转了 ¥5000。"我自己赚的。"' },
  { id: 'easter_paris', label: '🗼 巴黎 + 阿姆斯特丹', desc: '£250，10 天',
    effect: { energy: 12, wallet: -250, belonging: 18, academic: -3 },
    feedback: '你在巴黎地铁里被偷了一次手机。补办耽误了 2 天。但你也学会了——出门把钱分三处放。这种小课，留学才教得了你。' },
  { id: 'easter_home', label: '✈️ 回国 4 周', desc: '£800，但能见家人',
    effect: { energy: 30, wallet: -800, belonging: 35, academic: -10 },
    feedback: '4 周里你陪爷爷下了 50 盘棋，吃了无数顿火锅，参加了表姐的婚礼。临走时奶奶塞给你一袋老干妈。回伦敦你打开行李箱，眼泪掉到那袋老干妈上。' },
  { id: 'easter_intern', label: '💻 找了个无薪实习', desc: '+学业 +履历，但白干',
    effect: { energy: -15, academic: 15, belonging: 5, flag: 'easter_internship' },
    feedback: '你在一家小公司打杂 4 周。负责人最后说："你做得很好。我们没有正式岗位，但我可以给你写推荐信。" 你想，这就够了。' },
];

// ========================================
// 假期隐藏剧情（基于 NPC 关系/flag 解锁）
// ========================================

const HOLIDAY_SECRETS_XMAS = [
  {
    id: 'xmas_sarah_cotswolds',
    npc: 'sarah', emoji: '🌹',
    label: 'Sarah · 去 Cotswolds 过圣诞',
    desc: '英式家庭圣诞 · roast turkey + 女王讲话',
    condition: ({ npcRel }) => (npcRel.sarah || 0) >= 6,
    effect: { energy: 15, wallet: -100, belonging: 25, academic: 0, flag: 'cotswolds_xmas', rel: { sarah: 4 } },
    feedback: '你坐 Sarah 家的车开过 Cotswolds 起伏的山丘。圣诞夜她妈做了 turkey、三种 stuffing、布丁。爸爸打开收音机听女王讲话。Boxing Day 你们去了酒馆，Sarah 介绍你给镇上每个人："这是我朋友。"\n\n临走时她妈塞给你一个手织的围巾："I made this for you, dear." 你在火车上摸着围巾哭了 20 分钟。' },
  {
    id: 'xmas_aditi_india',
    npc: 'aditi', emoji: '💜',
    label: 'Aditi · 一起飞印度看望她爸爸',
    desc: '£500 · 10 天 · 孟买',
    condition: ({ npcRel, storyProgress }) => (npcRel.aditi || 0) >= 8 && (storyProgress.aditi || 0) >= 3,
    effect: { energy: -10, wallet: -500, belonging: 30, academic: -5, flag: 'visited_india', rel: { aditi: 5 } },
    feedback: 'Aditi 哭了一晚才说出口："Will you come with me? I can\'t face this alone."\n\n孟买 35 度。她爸爸瘦得让人心疼。但他认出你了——Aditi 给他看过你的照片。他用蹩脚的英文说："Thank you for coming with my daughter."\n\n10 天里你吃了一辈子的咖喱，看了一场宝莱坞，被拥抱过 50 次。回伦敦的飞机上 Aditi 睡着了，头靠在你肩膀上。你想，这一辈子我都会记得这一个圣诞。' },
  {
    id: 'xmas_wangkai_grind',
    npc: 'wangkai', emoji: '🥟',
    label: '王凯 · 跟他爆肝代购大单',
    desc: '3 周 · +£2500 · 代价惨重',
    condition: ({ npcRel, flags }) => (npcRel.wangkai || 0) >= 5 && flags.wangkai_business,
    effect: { energy: -35, wallet: 2500, belonging: 5, academic: -8, flag: 'xmas_grind', rel: { wangkai: 4 } },
    feedback: '王凯说圣诞是奶茶旺季。"哥们 干三周抵半年。"\n\n你们俩通宵了 11 个晚上。煮珍珠煮到手起泡。包装贴标签到凌晨 4 点。新年那天王凯扔给你一沓现金："£2500 你的。"\n\n你瘦了 4 公斤，黑眼圈下到颧骨。但这是你这辈子第一次靠自己赚到这么多钱。你给妈妈转了 ¥10000，留言："过年别省，给爸买双新鞋。"' },
  {
    id: 'xmas_mei_family',
    npc: 'mei', emoji: '🍜',
    label: 'Mei 姐 · 去她家过年',
    desc: '"傻孩子没回国就来我家吧"',
    condition: ({ npcRel, flags }) => (npcRel.mei || 0) >= 7 && flags.mei_job,
    effect: { energy: 10, wallet: -20, belonging: 35, academic: 0, flag: 'mei_family', rel: { mei: 5 } },
    feedback: 'Mei 姐家在 Croydon，二楼小红砖房。她老公是个寡言的福建男人，两个 ABC 儿子（一个 12 一个 8）见到你像见到了亲戚。\n\n Mei 姐做了 17 道菜。她说："傻孩子叫姨。"\n\n你叫了"姨"。她转身回厨房。你听见她在哭。\n\n你跟她两个儿子打了一晚 Mario Kart。临走时小儿子塞给你一颗糖："姐姐/哥哥下次来呀。" 你点头。' },
  {
    id: 'xmas_whitmore_dinner',
    npc: 'whitmore', emoji: '🎓',
    label: 'Whitmore · College High Table dinner',
    desc: '黑领结 · 学术 elite 圣诞晚宴',
    condition: ({ npcRel }) => (npcRel.whitmore || 0) >= 7,
    effect: { energy: -8, wallet: -80, belonging: 8, academic: 12, flag: 'high_table', rel: { whitmore: 3 } },
    feedback: 'Senior Common Room。20 个教授，每人一身黑领结/晚礼服。三道菜，餐前雪利酒，餐后波特酒。\n\n你坐在 Whitmore 旁边。他指了指对面那个白胡子老头："That\'s Lord Kerridge. Wrote the book on Hegel."\n\n你吃饭的手在抖。但你也听懂了 70% 的对话，甚至说了一个让 Lord Kerridge 笑出声的小笑话。\n\n回家路上你穿过 College 的 quad。雪刚下。你想：原来这就是英国学术圈。原来我可以坐在这桌上。' },
];

const HOLIDAY_SECRETS_EASTER = [
  {
    id: 'easter_sarah_eurotrip',
    npc: 'sarah', emoji: '🌹',
    label: 'Sarah · 一起欧洲背包穷游',
    desc: '3 周 · 5 个国家 · Interrail',
    condition: ({ npcRel, flags }) => (npcRel.sarah || 0) >= 8 && flags.cotswolds_visited,
    effect: { energy: 25, wallet: -550, belonging: 35, academic: -15, flag: 'eurotrip_sarah', rel: { sarah: 6 } },
    feedback: 'Interrail Pass £350。你们俩 21 天 5 个国家。\n\n巴黎你们爬到铁塔顶上，Sarah 说"I\'ve always wanted to do this with someone who\'d remember it." 你说"I\'ll remember."\n\n米兰你们在大教堂前吵了一架，又在吃完 gelato 后和好。雅典 Acropolis 上她突然问你："Are we friends? Like real friends?"\n\n你想了 5 秒。然后说"Yes."\n\n回伦敦的火车上你们没说话，就一起看着窗外。你知道，有些友谊就是这样炼成的。' },
  {
    id: 'easter_aditi_writing',
    npc: 'aditi', emoji: '💜',
    label: 'Aditi · 一起规划论文 + 健身房',
    desc: '4 周互相督促 · 论文起步',
    condition: ({ npcRel }) => (npcRel.aditi || 0) >= 6,
    effect: { energy: 5, wallet: -50, belonging: 20, academic: 18, flag: 'easter_aditi_pact', rel: { aditi: 4 } },
    feedback: '你们做了一个 pact：每天早上 7 点健身房，9 点图书馆，晚上 9 点互相 review 当天的写作。\n\n4 周下来你写了 3000 字论文 outline，瘦了 3 公斤，跑步从 5 分钟到 30 分钟不停。\n\n更重要的是，你们之间形成了一种你从来没体验过的友谊——不是浪漫，不是事务性的，就是：彼此让彼此变好。\n\n复活节最后一天你们坐在 Hyde Park 草地上。Aditi 说："This is the best Easter I\'ve had." 你点头。' },
  {
    id: 'easter_wangkai_apprentice',
    npc: 'wangkai', emoji: '🥟',
    label: '王凯 · 全权管店 4 周',
    desc: '+£1500 · 学完整套生意经',
    condition: ({ npcRel }) => (npcRel.wangkai || 0) >= 4,
    effect: { energy: -22, wallet: 1500, belonging: 6, academic: -3, flag: 'wangkai_apprentice', rel: { wangkai: 3 } },
    feedback: '王凯出差去广州进货 3 周。他把店钥匙、收银 PIN、银行卡都给了你。"哥们 这是 £30K 的生意 别砸了。"\n\n第一周你失眠。第二周你学会了和 Deliveroo 客服扯皮。第三周你发明了一个小红书引流的方法，单日订单破纪录。\n\n王凯回来看账本，半天没说话。然后说："我没看错你。" 他给你转了 £1500。\n\n这不是辛苦费，是工资。你有生以来第一次拿"工资"。' },
  {
    id: 'easter_whitmore_thesis',
    npc: 'whitmore', emoji: '🎓',
    label: 'Whitmore · 论文密集辅导',
    desc: '4 周 · 每周 2 次 · 论文起飞',
    condition: ({ npcRel }) => (npcRel.whitmore || 0) >= 8,
    effect: { energy: -10, wallet: 0, belonging: 12, academic: 25, flag: 'thesis_polished', rel: { whitmore: 4 } },
    feedback: 'Whitmore 假期没回家——他妻子去年走了，他不愿意一个人在乡下房子里待着。"So if you\'re free, let\'s use this time."\n\n4 周里你们每周二、周五各见一次。他逐字逐句读你的 proposal，红笔写满。他给你推荐了 7 本你从来没听说过的书。\n\n第三周他第一次叫了你的真名（不是英文名）。"你的名字很美。你应该用它发表论文。"\n\n复活节最后一次见面，他说："你的论文，我建议直接投 *Journal of Cultural Studies*。" 你愣了 10 秒。他笑了。"That\'s not a joke. Try it."' },
  {
    id: 'easter_mei_promotion',
    npc: 'mei', emoji: '🍜',
    label: 'Mei 姐 · 当 4 周餐厅经理',
    desc: '+£1800 · 真正的责任',
    condition: ({ npcRel, flags }) => (npcRel.mei || 0) >= 8 && flags.mei_family,
    effect: { energy: -20, wallet: 1800, belonging: 18, academic: -3, flag: 'mei_manager', rel: { mei: 4 } },
    feedback: 'Mei 姐说她要回福建一个月——她妈妈病了。"店里你管 4 周，£1800。我信你。"\n\n你管了。前三天你怀疑自己疯了。第二周你学会了和供货商砍价，搞定了一次员工矛盾。第四周你甚至改良了菜单——加了一道"留学生特价套餐"，£8.5 一份。\n\nMei 姐回来发现店里营业额涨了 18%。她坐下来，说："傻孩子。" 然后哭了。\n\n"姨没看错你。"' },
];

// ========================================
// Reading Week 事件
// ========================================

const READING_WEEK_EVENTS = [
  { id: 'rw_lucky', title: 'Reading Week 第一天', body: '没有课。整个伦敦的留学生都在做同一件事——睡到自然醒。',
    effect: { energy: 12, academic: 2 }, isAuto: true },
];

// ========================================
// 考试系统
// ========================================

const EXAM_PAPERS = [
  {
    id: 'exam_theory', subject: 'Critical Theory', cn: '批判理论',
    questions: [
      { q: 'Foucault 在《规训与惩罚》中如何定义权力？',
        options: ['一种自上而下的压制力', '弥散在社会关系中的微观结构', '国家机器的暴力', '经济基础的反映'],
        correct: 1 },
      { q: '后结构主义认为意义是：',
        options: ['固定的', '由 signifier 之间的差异生成的', '作者意图的还原', '客观世界的反映'],
        correct: 1 },
      { q: '"erasure under erasure" 是哪位理论家的概念？',
        options: ['Derrida', 'Foucault', 'Lacan', 'Žižek'],
        correct: 0 },
      { q: 'Said 的 Orientalism 主要批判：',
        options: ['西方的殖民历史', '西方对东方的话语建构', '东方学家学术不严谨', '所有跨文化研究'],
        correct: 1 },
      { q: 'Butler 的 performativity 是指：',
        options: ['表演性的虚假', '通过重复实践构成主体', '剧院理论的延伸', '社会角色扮演'],
        correct: 1 },
    ],
  },
  {
    id: 'exam_method', subject: 'Research Methods', cn: '研究方法',
    questions: [
      { q: 'Qualitative research 的核心特点是：',
        options: ['追求统计显著性', '理解意义和经验', '排除研究者主观性', '大规模数据收集'],
        correct: 1 },
      { q: '"thick description" 是哪位学者提出的？',
        options: ['Geertz', 'Bourdieu', 'Goffman', 'Garfinkel'],
        correct: 0 },
      { q: 'Triangulation 在研究中指的是：',
        options: ['三角形采样', '使用多种方法验证', '三个研究者合作', '三阶段数据分析'],
        correct: 1 },
      { q: 'IRB approval 在英国大学称为：',
        options: ['Ethics Committee', 'Research Board', 'Senate Committee', 'Faculty Review'],
        correct: 0 },
      { q: '半结构化访谈最适合：',
        options: ['大样本调查', '探索性研究', '实验对照', '内容分析'],
        correct: 1 },
    ],
  },
  {
    id: 'exam_dissert_prep', subject: 'Dissertation Prep', cn: '论文准备',
    questions: [
      { q: '一个好的研究问题需要：',
        options: ['有现成答案', '可被研究、有意义、可控范围', '导师指定', '紧跟热点'],
        correct: 1 },
      { q: 'Literature gap 指的是：',
        options: ['找不到文献', '已有研究尚未涵盖的领域', '文献质量不高', '过时的研究'],
        correct: 1 },
      { q: 'UK Master 论文一般字数是：',
        options: ['5,000-10,000', '12,000-15,000', '20,000+', '30,000+'],
        correct: 1 },
      { q: '提交论文时常见的格式要求不包括：',
        options: ['Harvard 引用', '双倍行距', '12 号字', '强制使用宋体'],
        correct: 3 },
      { q: 'Viva 是指：',
        options: ['期末聚会', '论文答辩', '小组报告', '欢呼仪式'],
        correct: 1 },
    ],
  },
];

// ========================================
// 论文（Dissertation）事件 / 选择
// ========================================

const DISSERTATION_TOPICS = [
  { id: 'safe', label: '保守题目（导师推荐的方向）', desc: '风险低，分数稳，但可能拿不到distinction',
    effect: { academic: 5, energy: -5 },
    flag: 'diss_safe',
    feedback: 'Whitmore 看完你的 proposal 点头："Solid. Predictable but solid." 你知道这就是你这一年的总结。' },
  { id: 'ambitious', label: '冒险题目（你自己想做的方向）', desc: '风险高，但可能拿到distinction',
    effect: { academic: 8, energy: -10 },
    flag: 'diss_ambitious',
    feedback: 'Whitmore 看完皱了眉："This is ambitious. Are you sure?" 你说你确定。他叹气，然后笑了。"Then I\'ll help you do it well."' },
  { id: 'personal', label: '个人化题目（关于你自己的留学经历）', desc: '风险极高，但有特别意义',
    effect: { academic: 6, energy: -8, belonging: 10 },
    flag: 'diss_personal',
    feedback: '你的题目是关于"中国留学生在英国的身份建构"。Whitmore 沉默了很久，然后说："This will be hard to write. But you should write it."' },
];

// ========================================
// 迷你游戏：Pret 点餐听力
// ========================================

const PRET_QUESTIONS = [
  {
    staff: '"What can I get you, love?"',
    options: [
      { text: 'A flat white please', correct: true, feedback: '"Lovely, anything else?"' },
      { text: 'Yes', correct: false, feedback: '店员愣了一下："...yes what?"' },
      { text: 'I don\'t know', correct: false, feedback: '店员忍住没翻白眼。' },
    ],
  },
  {
    staff: '"For here or takeaway?"',
    options: [
      { text: 'Takeaway please', correct: true, feedback: '"Cool."' },
      { text: '"For here please" 但你其实想外带', correct: false, feedback: '你不敢改口。最后捧着杯子站着喝完了。' },
      { text: '"Both?"', correct: false, feedback: '店员笑了："Choose one, love."' },
    ],
  },
  {
    staff: '"That\'ll be 4.85, please. Cash or card?"',
    options: [
      { text: '递卡', correct: true, feedback: '"Tap or insert?"' },
      { text: '"Card... I think?"', correct: false, feedback: '店员等了 5 秒。后面的人开始翻白眼。' },
      { text: '掏出现金', correct: false, feedback: '店员说"Sorry love, we\'re cashless." 你拿着 £20 现金愣住。' },
    ],
  },
  {
    staff: '"Would you like a paper bag? It\'s 10p."',
    options: [
      { text: '"No thanks"', correct: true, feedback: '"Cheers."' },
      { text: '点头但没说话', correct: false, feedback: '店员看着你："...is that a yes or a no?"' },
      { text: '"What does that mean?"', correct: false, feedback: '店员耐心解释了 30 秒。后面排队的人脸都黑了。' },
    ],
  },
  {
    staff: '"Have a lovely day!"',
    options: [
      { text: '"You too!"', correct: true, feedback: '你接住了。这是你今天最自然的英语对话。' },
      { text: '"Thanks"', correct: false, feedback: '没错但缺了点温度。' },
      { text: '"Same to you!"', correct: false, feedback: '"Same to you" 也行，但有点僵。' },
    ],
  },
];

// ========================================
// 迷你游戏：写论文（句子选择）
// ========================================

const ESSAY_PUZZLES = [
  {
    context: '论文段落 · 引言',
    paragraph: 'This dissertation examines the experience of Chinese international students in the UK. ___ Drawing on qualitative interviews, it argues that belonging is not a static state but a continuous negotiation.',
    options: [
      { text: 'Specifically, it focuses on how identity is negotiated in cross-cultural settings.', correct: true,
        feedback: '✓ 这个句子精确连接了"主题"和"方法"。Whitmore 写："Excellent transition."' },
      { text: 'I interviewed many people for this paper.', correct: false,
        feedback: '✗ 太口语，"I" 在学术写作里要慎用。Whitmore 写："Avoid first person."' },
      { text: 'Chinese students are very interesting to study.', correct: false,
        feedback: '✗ 太宽泛，缺乏论点。Whitmore 写："What is your argument?"' },
      { text: 'In this essay, I will discuss many things.', correct: false,
        feedback: '✗ "discuss many things" = 没有焦点。这是大一新生的写法。' },
    ],
  },
  {
    context: '论文段落 · 文献综述',
    paragraph: 'Bourdieu\'s concept of habitus has been widely used in studies of migration. ___ However, recent scholarship has questioned its applicability to digitally connected migrants.',
    options: [
      { text: 'It captures how dispositions are shaped by social structures.', correct: true,
        feedback: '✓ 用一句话精准定义概念，再引出反驳。这是研究生水平。' },
      { text: 'Many people have written about it.', correct: false,
        feedback: '✗ 完全空洞。' },
      { text: 'It\'s a complicated theory.', correct: false,
        feedback: '✗ "complicated" 是描述，不是论证。' },
      { text: 'Bourdieu was a French sociologist.', correct: false,
        feedback: '✗ 这个是百科信息，不是文献综述。' },
    ],
  },
  {
    context: '论文段落 · 结论',
    paragraph: 'These findings suggest that the experience of "异乡" cannot be reduced to a binary of integration or alienation. ___ Future research might explore how this in-between state is articulated across different generations of migrants.',
    options: [
      { text: 'It is, rather, a continually shifting affective terrain.', correct: true,
        feedback: '✓ 优雅，且把核心概念升华了。Whitmore："This is the sentence the whole thesis was building toward."' },
      { text: 'It is more complex than that.', correct: false,
        feedback: '✗ "more complex" 太懒——具体怎么 complex？' },
      { text: 'Therefore, I am right.', correct: false,
        feedback: '✗ 学术写作不要这么"赢"。' },
      { text: 'In conclusion, China is far away.', correct: false,
        feedback: '✗ 既不准确也不学术。' },
    ],
  },
];

// ========================================
// 迷你游戏：理论家概念匹配
// ========================================

const THEORIST_MATCH = {
  theorists: [
    { id: 'foucault', name: 'Foucault', concepts: ['discipline', 'biopower', 'panopticon'] },
    { id: 'bourdieu', name: 'Bourdieu', concepts: ['habitus', 'cultural_capital', 'field'] },
    { id: 'butler', name: 'Butler', concepts: ['performativity', 'gender_trouble'] },
    { id: 'said', name: 'Said', concepts: ['orientalism'] },
  ],
  concepts: {
    discipline: { label: 'Discipline', desc: '规训' },
    biopower: { label: 'Biopower', desc: '生命权力' },
    panopticon: { label: 'Panopticon', desc: '全景监狱' },
    habitus: { label: 'Habitus', desc: '惯习' },
    cultural_capital: { label: 'Cultural Capital', desc: '文化资本' },
    field: { label: 'Field', desc: '场域' },
    performativity: { label: 'Performativity', desc: '操演性' },
    gender_trouble: { label: 'Gender Trouble', desc: '性别麻烦' },
    orientalism: { label: 'Orientalism', desc: '东方主义' },
  },
};

// ========================================
// 主组件
// ========================================

export default function App() {
  const [screen, setScreen] = useState('intro');
  const [day, setDay] = useState(1);
  const [stats, setStats] = useState({ academic: 30, wallet: 800, energy: 80, belonging: 20 });
  const [npcRel, setNpcRel] = useState({ sarah: 0, wangkai: 0, aditi: 0, whitmore: 0, mei: 0 });
  const [storyProgress, setStoryProgress] = useState({ sarah: 0, mei: 0, wangkai: 0, aditi: 0, whitmore: 0 });
  const [flags, setFlags] = useState({});
  const [seenLocationEvents, setSeenLocationEvents] = useState({});
  const [messages, setMessages] = useState([]);
  const [unreadMessages, setUnreadMessages] = useState(0);
  const [muted, setMuted] = useState(false);
  const [tab, setTab] = useState('map');
  const [currentLocation, setCurrentLocation] = useState(null);
  const [activeEvent, setActiveEvent] = useState(null);
  const [activeStoryChapter, setActiveStoryChapter] = useState(null);
  const [activeNpcDialog, setActiveNpcDialog] = useState(null);
  const [activeMinigame, setActiveMinigame] = useState(null);
  const [eventFeedback, setEventFeedback] = useState(null);
  const [travelMode, setTravelMode] = useState(null);
  const [travelEventsSeen, setTravelEventsSeen] = useState({}); // { edinburgh: ['arthurs_seat'], ... }
  const [postcards, setPostcards] = useState([]); // 明信片收集
  const [travelDayUsed, setTravelDayUsed] = useState(0);
  const [activeTravelEvent, setActiveTravelEvent] = useState(null);

  // V7 新增
  const [weekWeather, setWeekWeather] = useState({}); // { week: 'sunny' }
  const [seenFestivals, setSeenFestivals] = useState([]);
  const [seenWeatherEvents, setSeenWeatherEvents] = useState([]);
  const [groupChat, setGroupChat] = useState([]); // 已显示的群消息
  const [seenGroupWeeks, setSeenGroupWeeks] = useState([]);
  const [unreadGroup, setUnreadGroup] = useState(0);
  const [activeMinigamePret, setActiveMinigamePret] = useState(false);
  const [activeMinigameEssay, setActiveMinigameEssay] = useState(false);
  const [activeMinigameMatch, setActiveMinigameMatch] = useState(false);
  const [birthdayMonth, setBirthdayMonth] = useState(null); // 玩家生日月（1-12）
  const [showBirthdayPrompt, setShowBirthdayPrompt] = useState(false);
  const [birthdayCelebrated, setBirthdayCelebrated] = useState(false);

  // V8 新增
  const [addedStrangers, setAddedStrangers] = useState([]); // 已加好友的陌生人 id
  const [activeStrangerEvent, setActiveStrangerEvent] = useState(null); // 偶遇陌生人的事件
  const [seenAtYouEvents, setSeenAtYouEvents] = useState([]);
  const [activeAtYouEvent, setActiveAtYouEvent] = useState(null);
  const [activeDream, setActiveDream] = useState(null);
  const [seenDreams, setSeenDreams] = useState([]);
  const [activeInsomnia, setActiveInsomnia] = useState(null);
  const [seenInsomnia, setSeenInsomnia] = useState([]);
  const [activeNostalgia, setActiveNostalgia] = useState(null);
  const [seenNostalgia, setSeenNostalgia] = useState([]);

  // V9 新增
  const [strangerAddedAt, setStrangerAddedAt] = useState({}); // { xiao_li: 5 (week added) }
  const [seenStrangerEvents, setSeenStrangerEvents] = useState([]);
  const [activeStrangerEventModal, setActiveStrangerEventModal] = useState(null);
  const [nostalgiaCount, setNostalgiaCount] = useState(0);
  const [activeCrisis, setActiveCrisis] = useState(null);
  const [crisisTriggered, setCrisisTriggered] = useState(false);
  const [seenDiaryTab, setSeenDiaryTab] = useState(false); // for unread badge

  // V10 父母线
  const [parentsChapter, setParentsChapter] = useState(0); // 当前进度
  const [activeParentsChapter, setActiveParentsChapter] = useState(null);
  const [parentsCallTrigger, setParentsCallTrigger] = useState(false); // 是否需要在call_home后触发ch1
  const [classesAttendedThisWeek, setClassesAttendedThisWeek] = useState(0);
  const [attendanceHistory, setAttendanceHistory] = useState([]);
  const [showStoryNotification, setShowStoryNotification] = useState(null);
  const [ending, setEnding] = useState(null);

  // V5 新增：日历相关状态
  const [holidayChoice, setHolidayChoice] = useState(null); // 'xmas_done', 'easter_done'
  const [showHolidayScreen, setShowHolidayScreen] = useState(null); // 'xmas' | 'easter'
  const [activeExam, setActiveExam] = useState(null); // 当前正在考的试卷
  const [examResults, setExamResults] = useState({}); // { exam_theory: 75, ... }
  const [dissertationProgress, setDissertationProgress] = useState(0); // 0-100
  const [dissertationTopic, setDissertationTopic] = useState(null);
  const [showDissertationTopicScreen, setShowDissertationTopicScreen] = useState(false);
  const [monthAttendance, setMonthAttendance] = useState([]); // [{ month, attended, required, rate }]

  const TOTAL_DAYS = 364; // 52 周
  const DAILY_ACTIONS = 3;
  const [actionsLeft, setActionsLeft] = useState(DAILY_ACTIONS);
  const [seenChapters, setSeenChapters] = useState([]);

  const week = Math.ceil(day / 7);
  const dayOfWeek = ((day - 1) % 7) + 1;
  const isWeekend = dayOfWeek === 6 || dayOfWeek === 7;
  const weekInfo = getWeekInfo(week);
  // 仅基于上课周计算出勤
  const classWeeks = attendanceHistory.filter(a => (a.required || 4) > 0);
  const totalAttended = classWeeks.reduce((s, h) => s + h.attended, 0);
  const totalRequired = classWeeks.reduce((s, h) => s + (h.required || 4), 0);
  const attendanceRate = totalRequired > 0 ? Math.round((totalAttended / totalRequired) * 100) : 100;
  // 当月出勤
  const currentMonthRate = monthAttendance.length > 0 ? monthAttendance[monthAttendance.length - 1].rate : null;

  // 音频
  useEffect(() => { audio.init(); audio.setMuted(muted); }, [muted]);
  useEffect(() => {
    if (muted) return;
    if (screen === 'playing') {
      const isWinter = week >= 9 && week <= 16;
      if (isWinter) audio.startRain(0.3); else audio.startQuiet();
    } else audio.stopAmbient();
    return () => audio.stopAmbient();
  }, [screen, muted, week]);

  function startGame() {
    audio.init(); audio.click();
    setShowBirthdayPrompt(true);
  }

  function setBirthdayAndStart(month) {
    audio.click();
    setBirthdayMonth(month);
    setShowBirthdayPrompt(false);
    setScreen('playing');
    // 生成第 1 周天气
    setWeekWeather({ 1: generateWeekWeather(1) });
    addMessage('mom', '🇨🇳 妈妈', '到了吗？给妈报个平安');
    setTimeout(() => addMessage('sarah', 'Sarah', 'Hey! Welcome to UK 🇬🇧 see you in class!'), 500);
  }

  function addMessage(from, fromName, text) {
    const newMsg = { id: Date.now() + Math.random(), from, fromName, text, day, time: new Date().toLocaleTimeString().slice(0,5), read: false };
    setMessages(m => [...m, newMsg]);
    setUnreadMessages(c => c + 1);
    audio.message();
  }

  // 进入地点
  function goToLocation(loc) {
    if (actionsLeft <= 0) return;
    audio.click();
    setActionsLeft(actionsLeft - 1);
    setCurrentLocation(loc);
    // 天气影响精力消耗
    const w = WEATHERS[weekWeather[week] || 'cloudy'];
    const energyCost = 5 - (w.energyMod || 0); // energyMod 是负数会增加消耗
    setStats(s => ({ ...s, energy: clamp(s.energy - energyCost, 0, 100) }));

    // 优先级 1：剧情线触发
    const triggeredChapter = checkStoryTriggers(loc.id);
    if (triggeredChapter) {
      setTimeout(() => {
        setActiveStoryChapter(triggeredChapter);
        audio.ding();
      }, 400);
      return;
    }

    // 优先级 2：NPC 关系网事件
    const networkEvent = checkNetworkEvent(loc.id);
    if (networkEvent) {
      setTimeout(() => {
        setActiveEvent(networkEvent);
        audio.ding();
        setSeenLocationEvents(s => ({ ...s, _network: [...(s._network || []), networkEvent.id] }));
      }, 400);
      return;
    }

    // 优先级 3：天气专属事件
    const weatherEvent = checkWeatherEvent(loc.id);
    if (weatherEvent) {
      setTimeout(() => {
        setActiveEvent(weatherEvent);
        audio.ding();
        setSeenWeatherEvents([...seenWeatherEvents, weatherEvent.id]);
      }, 400);
      return;
    }

    // 优先级 4：陌生人偶遇（如果未加该 stranger）
    const stranger = STRANGERS.find(s => s.metAt === loc.id && !addedStrangers.includes(s.id));
    if (stranger && week >= 3 && Math.random() < 0.35) {
      setTimeout(() => {
        setActiveStrangerEvent(stranger);
        audio.message();
      }, 400);
      return;
    }

    // 优先级 5：普通地点事件
    const events = LOCATION_EVENTS[loc.id] || [];
    const eligible = events.filter(ev => {
      if (week < (ev.minWeek || 1)) return false;
      if (!ev.repeatable && (seenLocationEvents[loc.id] || []).includes(ev.id)) return false;
      return true;
    });
    if (eligible.length > 0 && Math.random() < 0.5) {
      const ev = eligible[Math.floor(Math.random() * eligible.length)];
      setTimeout(() => {
        setActiveEvent(ev);
        if (!ev.repeatable) setSeenLocationEvents(s => ({ ...s, [loc.id]: [...(s[loc.id] || []), ev.id] }));
      }, 300);
    }
  }

  // 处理陌生人偶遇
  function addStranger(stranger) {
    audio.click();
    setAddedStrangers([...addedStrangers, stranger.id]);
    setStrangerAddedAt(s => ({ ...s, [stranger.id]: week }));
    // 把欢迎消息插入群聊
    setGroupChat(prev => [...prev, {
      from: stranger.id,
      text: stranger.welcomeMsg,
      id: `stranger-${stranger.id}-${Date.now()}`,
      week,
      time: new Date().toLocaleTimeString().slice(0,5),
    }]);
    setUnreadGroup(c => c + 1);
    setStats(s => ({ ...s, energy: clamp(s.energy - 2, 0, 100), belonging: clamp(s.belonging + 4, 0, 100) }));
    setActiveStrangerEvent(null);
  }

  function rejectStranger() {
    audio.click();
    setStats(s => ({ ...s, energy: clamp(s.energy - 1, 0, 100), belonging: clamp(s.belonging - 1, 0, 100) }));
    setActiveStrangerEvent(null);
  }

  // 检查天气事件
  function checkWeatherEvent(locId) {
    const currentWeather = weekWeather[week];
    if (!currentWeather) return null;
    for (const ev of WEATHER_EVENTS) {
      if (ev.weather !== currentWeather) continue;
      if (week < (ev.minWeek || 1)) continue;
      if (!ev.repeatable && seenWeatherEvents.includes(ev.id)) continue;
      // 一些 weather event 不限定地点；要求在某些场景出现
      if (ev.weather === 'rain' && !['flat', 'uni'].includes(locId)) continue;
      if (ev.weather === 'fog' && locId === 'flat') continue; // 雾天必须出门才有
      if (ev.weather === 'snow' && locId === 'flat') continue;
      if (ev.weather === 'sunny' && !['park', 'camden', 'tate'].includes(locId)) continue;
      if (Math.random() < 0.4) return ev;
    }
    return null;
  }

  // 检查 NPC 关系网事件（基于多 NPC 关系组合触发）
  function checkNetworkEvent(locId) {
    const seen = seenLocationEvents._network || [];
    for (const ev of NPC_NETWORK_EVENTS) {
      if (seen.includes(ev.id)) continue;
      if (ev.location !== locId) continue;
      if (!ev.condition({ npcRel, storyProgress, flags })) continue;
      // 自动触发的事件直接返回；非自动的有 50% 概率
      if (ev.auto || Math.random() < 0.5) return ev;
    }
    return null;
  }

  // 检查剧情线触发
  function checkStoryTriggers(locId) {
    for (const lineId of Object.keys(STORYLINES)) {
      const line = STORYLINES[lineId];
      const progress = storyProgress[lineId] || 0;
      if (progress >= line.chapters.length) continue;
      const chapter = line.chapters[progress];
      if (seenChapters.includes(chapter.id)) continue;
      const t = chapter.trigger;
      const npc = line.npc;
      if (t.location && t.location !== locId) continue;
      if (t.rel !== undefined && (npcRel[npc] || 0) < t.rel) continue;
      if (t.flag && !flags[t.flag]) continue;
      return { lineId, chapter };
    }
    return null;
  }

  // 选择剧情选项
  function chooseStoryOption(choice) {
    audio.click();
    const eff = choice.effect;
    const newStats = {
      academic: clamp(stats.academic + (eff.academic || 0), 0, 100),
      wallet: stats.wallet + (eff.wallet || 0),
      energy: clamp(stats.energy + (eff.energy || 0), 0, 100),
      belonging: clamp(stats.belonging + (eff.belonging || 0), 0, 100),
    };
    setStats(newStats);
    if (eff.rel && activeStoryChapter) {
      const npcId = STORYLINES[activeStoryChapter.lineId].npc;
      setNpcRel(r => ({ ...r, [npcId]: (r[npcId] || 0) + eff.rel }));
    }
    if (eff.flag) setFlags(f => ({ ...f, [eff.flag]: true }));
    setEventFeedback(choice.feedback);
    if (activeStoryChapter) {
      setSeenChapters(s => [...s, activeStoryChapter.chapter.id]);
      setStoryProgress(p => ({ ...p, [activeStoryChapter.lineId]: (p[activeStoryChapter.lineId] || 0) + 1 }));
      setShowStoryNotification(STORYLINES[activeStoryChapter.lineId].name);
      setTimeout(() => setShowStoryNotification(null), 3000);
    }
  }

  // 选择普通事件选项
  function chooseEventOption(choice) {
    audio.click();
    const eff = choice.effect;
    const newStats = {
      academic: clamp(stats.academic + (eff.academic || 0), 0, 100),
      wallet: stats.wallet + (eff.wallet || 0),
      energy: clamp(stats.energy + (eff.energy || 0), 0, 100),
      belonging: clamp(stats.belonging + (eff.belonging || 0), 0, 100),
    };
    setStats(newStats);
    // 支持 npc 关系变化（用于 NPC 关系网事件）
    if (eff.npc) {
      setNpcRel(r => {
        const next = { ...r };
        Object.entries(eff.npc).forEach(([id, delta]) => {
          next[id] = (next[id] || 0) + delta;
        });
        return next;
      });
    }
    setEventFeedback(choice.feedback);
  }

  // 完成事件返回
  function dismissEvent() {
    audio.click();
    setActiveEvent(null);
    setActiveStoryChapter(null);
    setEventFeedback(null);
    setCurrentLocation(null);
  }

  // 在大学上课
  function attendClass() {
    if (actionsLeft <= 0) return;
    audio.click();
    setActionsLeft(actionsLeft - 1);
    setStats(s => ({
      academic: clamp(s.academic + 6, 0, 100),
      wallet: s.wallet, energy: clamp(s.energy - 8, 0, 100),
      belonging: s.belonging,
    }));
    setClassesAttendedThisWeek(c => c + 1);
    setCurrentLocation(null);
  }

  // 打工
  function workShift() {
    if (actionsLeft <= 0) return;
    audio.click();
    setActionsLeft(actionsLeft - 1);
    setStats(s => ({
      academic: clamp(s.academic - 2, 0, 100),
      wallet: s.wallet + 50, energy: clamp(s.energy - 12, 0, 100),
      belonging: clamp(s.belonging + 1, 0, 100),
    }));
    setCurrentLocation(null);
  }

  // 在公寓休息
  function restAtFlat() {
    if (actionsLeft <= 0) return;
    audio.click();
    setActionsLeft(actionsLeft - 1);
    setStats(s => ({
      academic: s.academic, wallet: s.wallet,
      energy: clamp(s.energy + 25, 0, 100),
      belonging: clamp(s.belonging - 1, 0, 100),
    }));
    setCurrentLocation(null);
  }

  // 给家里打电话
  function callHome() {
    if (actionsLeft <= 0) return;
    audio.click();
    setActionsLeft(actionsLeft - 1);
    setStats(s => ({
      academic: s.academic, wallet: s.wallet,
      energy: clamp(s.energy - 3, 0, 100),
      belonging: clamp(s.belonging + 10, 0, 100),
    }));
    setCurrentLocation(null);
    addMessage('mom', '🇨🇳 妈妈', '挂了电话妈妈又转了 500 块给你 😊');

    // 父母线第 1 章触发（W6 之后，电话后 40% 概率）
    if (week >= 6 && parentsChapter === 0 && !flags.parents_declined && Math.random() < 0.4) {
      const ch1 = PARENTS_STORY.find(p => p.id === 'parents_1_offer');
      setTimeout(() => {
        setActiveParentsChapter(ch1);
        audio.ding();
      }, 800);
    }
  }

  // 父母线选项处理
  function chooseParentsChapter(choice) {
    audio.click();
    const eff = choice.effect;
    setStats(s => ({
      academic: clamp(s.academic + (eff.academic || 0), 0, 100),
      wallet: s.wallet + (eff.wallet || 0),
      energy: clamp(s.energy + (eff.energy || 0), 0, 100),
      belonging: clamp(s.belonging + (eff.belonging || 0), 0, 100),
    }));
    if (eff.flag) setFlags(f => ({ ...f, [eff.flag]: true }));
    setEventFeedback(choice.feedback);
  }

  function dismissParentsChapter() {
    audio.click();
    const ch = activeParentsChapter;
    setParentsChapter(ch.chapter);
    setActiveParentsChapter(null);
    setEventFeedback(null);
  }

  // 找 NPC 聊天
  function talkToNPC(npc) {
    audio.click();
    setActiveNpcDialog(npc);
  }

  // 在 NPC 对话中选话题
  function chooseNpcTopic(topic) {
    audio.click();
    const eff = topic.effect;
    setStats(s => ({
      academic: clamp(s.academic + (eff.academic || 0), 0, 100),
      wallet: s.wallet + (eff.wallet || 0),
      energy: clamp(s.energy + (eff.energy || 0), 0, 100),
      belonging: clamp(s.belonging + (eff.belonging || 0), 0, 100),
    }));
    if (eff.rel && activeNpcDialog) {
      setNpcRel(r => ({ ...r, [activeNpcDialog.id]: (r[activeNpcDialog.id] || 0) + eff.rel }));
    }
    setEventFeedback(topic.feedback);
  }

  function dismissNpcDialog() {
    audio.click();
    setActiveNpcDialog(null);
    setEventFeedback(null);
    setCurrentLocation(null);
  }

  // 推进一天
  function endDay() {
    audio.click();
    let newDay = day + 1;
    const newWeek = Math.ceil(newDay / 7);
    const oldWeekInfo = getWeekInfo(week);
    const newWeekInfo = getWeekInfo(newWeek);

    // 如果是周日，结算这一周
    if (dayOfWeek === 7) {
      // 只在需要上课的周记入出勤
      if (oldWeekInfo.requireClass) {
        const newAttendance = [...attendanceHistory, { week, attended: classesAttendedThisWeek, required: 4 }];
        setAttendanceHistory(newAttendance);

        // 按月计算（每 4 个 requireClass 周 = 1 个月）
        const requireClassWeeks = newAttendance.filter(a => a.required > 0);
        if (requireClassWeeks.length > 0 && requireClassWeeks.length % 4 === 0) {
          // 计算最近一个月（4周）出勤
          const lastMonth = requireClassWeeks.slice(-4);
          const monthAtt = lastMonth.reduce((s, a) => s + a.attended, 0);
          const monthReq = lastMonth.reduce((s, a) => s + a.required, 0);
          const monthRate = Math.round((monthAtt / monthReq) * 100);
          const monthNum = monthAttendance.length + 1;
          setMonthAttendance([...monthAttendance, { month: monthNum, attended: monthAtt, required: monthReq, rate: monthRate }]);

          // 月度警告
          if (monthRate < 60) {
            addMessage('uni', 'International Office', `⚠️ Month ${monthNum} attendance: ${monthRate}%. Below 60% requires immediate meeting. Risk of visa curtailment.`);
            audio.warning();
          } else if (monthRate < 70) {
            addMessage('uni', 'International Office', `📋 Month ${monthNum} attendance: ${monthRate}%. We are monitoring this closely.`);
          } else if (monthRate < 80) {
            addMessage('uni', 'Personal Tutor', `Hi, just checking in—your attendance this month was ${monthRate}%. Anything we can help with?`);
          }
        }
      }
      setClassesAttendedThisWeek(0);

      // 累计出勤率（仅基于上课周）
      const allClassWeeks = [...attendanceHistory.filter(a => a.required > 0)];
      if (oldWeekInfo.requireClass) {
        allClassWeeks.push({ week, attended: classesAttendedThisWeek, required: 4 });
      }
      const totalAtt = allClassWeeks.reduce((s, a) => s + a.attended, 0);
      const totalReq = allClassWeeks.reduce((s, a) => s + a.required, 0);
      const newRate = totalReq > 0 ? Math.round((totalAtt / totalReq) * 100) : 100;

      // 房租（任何时候都要交）
      setStats(s => ({ ...s, wallet: s.wallet - 320 }));

      // 签证危险
      if (newRate < 50 && week >= 4 && allClassWeeks.length >= 4) {
        setEnding({ title: '签证撤销', subtitle: 'Visa Curtailed',
          text: `Home Office 的信件比想象中简洁。"Your visa has been curtailed."\n\n累计出勤率 ${newRate}%。学校已上报。\n\n28 天内离境。\n\n那些你以为不重要的早 9 课，原来真的会决定你的一切。` });
        setScreen('ending'); audio.warning();
        return;
      }
    }

    setActionsLeft(DAILY_ACTIONS);
    setStats(s => ({ ...s, energy: clamp(s.energy + 15, 0, 100) }));

    if (newDay > TOTAL_DAYS) {
      generateEnding();
      return;
    }
    if (stats.wallet < 0) {
      setEnding({ title: '回去', subtitle: 'Going Home',
        text: '你撑不下去了。机票订在两周后。\n\n你给爸妈打电话，没敢说真话。' });
      setScreen('ending');
      return;
    }

    // === 检查特殊周开始 ===
    // 进入圣诞假期（week 13 开始）
    if (newWeek === 13 && week === 12 && holidayChoice !== 'xmas_done') {
      setShowHolidayScreen('xmas');
      setDay(newDay); setCurrentLocation(null);
      return;
    }
    // 进入复活节假期（week 27）
    if (newWeek === 27 && week === 26 && holidayChoice !== 'easter_done') {
      setShowHolidayScreen('easter');
      setDay(newDay); setCurrentLocation(null);
      return;
    }
    // 考试周开始（week 34/35/36 第一天）
    if (newWeekInfo.isExam && newWeek !== week) {
      const examIdx = newWeekInfo.examNumber - 1;
      const exam = EXAM_PAPERS[examIdx];
      if (exam && !examResults[exam.id]) {
        setActiveExam(exam);
        setDay(newDay); setCurrentLocation(null);
        return;
      }
    }
    // 论文季开始（week 37）—— 让玩家选题
    if (newWeek === 37 && week === 36 && !dissertationTopic) {
      setShowDissertationTopicScreen(true);
      setDay(newDay); setCurrentLocation(null);
      return;
    }
    // Reading week 自动事件
    if (newWeekInfo.type === 'reading' && newWeekInfo.week !== oldWeekInfo.week) {
      addMessage('uni', 'Faculty Office', '📅 Reminder: This week is Reading Week. No classes scheduled. Catch up on readings or take a break.');
    }

    // === V7：进入新周时触发系统 ===
    if (newWeek !== week) {
      // 1. 生成新周天气
      if (!weekWeather[newWeek]) {
        setWeekWeather(w => ({ ...w, [newWeek]: generateWeekWeather(newWeek) }));
      }

      // 2. 检查节日
      const festival = FESTIVALS[newWeek];
      if (festival && !seenFestivals.includes(festival.id)) {
        const fEvent = FESTIVAL_EVENTS[festival.id];
        if (fEvent) {
          setTimeout(() => {
            setActiveEvent({
              id: festival.id, tag: 'festival',
              title: fEvent.title, body: fEvent.body, choices: fEvent.choices,
              isFestival: true,
            });
            audio.ding();
          }, 600);
          setSeenFestivals([...seenFestivals, festival.id]);
          // 春节会触发思乡时刻（在节日事件之后）
          if (festival.id === 'spring_festival') {
            setTimeout(() => triggerNostalgia('spring_festival'), 3500);
          }
        }
      }

      // 2.5 随机思乡（精力很低 + 归属低 + 不在假期里）
      if (!festival && stats.belonging < 30 && stats.energy < 40 && Math.random() < 0.06) {
        const randomMoments = NOSTALGIA_MOMENTS.filter(m => m.trigger === 'random' && !seenNostalgia.includes(m.id));
        if (randomMoments.length > 0) {
          const m = randomMoments[Math.floor(Math.random() * randomMoments.length)];
          setTimeout(() => {
            setActiveNostalgia(m);
            audio.message();
          }, 1500);
          setSeenNostalgia([...seenNostalgia, m.id]);
        }
      }

      // 3. 检查生日（开学是 9 月 = 月 1，对应 week 1-4 ≈ 9月，5-8 ≈ 10月，etc.）
      if (birthdayMonth && !birthdayCelebrated) {
        // 9 月 = 月 1 (week 1-4), 10 月 = 月 2 (week 5-8) ...
        const calendarMonth = ((Math.floor((newWeek - 1) / 4) + 8) % 12) + 1; // 9月起算
        if (calendarMonth === birthdayMonth) {
          setTimeout(() => triggerBirthday(), 800);
          setBirthdayCelebrated(true);
        }
      }

      // 4. 检查群消息
      const groupMsg = GROUP_MESSAGES.find(m => m.week === newWeek && !seenGroupWeeks.includes(m.week));
      if (groupMsg) {
        setGroupChat(prev => [...prev, ...groupMsg.messages.map((msg, i) => ({
          ...msg, id: `${newWeek}-${i}`, week: newWeek, time: new Date().toLocaleTimeString().slice(0,5),
        }))]);
        setSeenGroupWeeks([...seenGroupWeeks, newWeek]);
        setUnreadGroup(c => c + groupMsg.messages.length);
        audio.message();
      }

      // 5. 检查 @你 事件
      const atEvent = AT_YOU_EVENTS.find(e =>
        e.week === newWeek && !seenAtYouEvents.includes(e.id) &&
        (!e.condition || e.condition({ npcRel, stats, flags }))
      );
      if (atEvent) {
        setTimeout(() => {
          setActiveAtYouEvent(atEvent);
          audio.message();
        }, 1200);
        setSeenAtYouEvents([...seenAtYouEvents, atEvent.id]);
      }

      // 6. 检查陌生人专属事件
      const strangerEv = STRANGER_EVENTS.find(e => {
        if (seenStrangerEvents.includes(e.id)) return false;
        if (!addedStrangers.includes(e.strangerId)) return false;
        const addedWeek = strangerAddedAt[e.strangerId];
        if (!addedWeek) return false;
        if (newWeek - addedWeek < e.weeksAfter) return false;
        if (e.requireFlag && !flags[e.requireFlag]) return false;
        return true;
      });
      if (strangerEv) {
        setTimeout(() => {
          setActiveStrangerEventModal(strangerEv);
          audio.ding();
        }, 1800);
        setSeenStrangerEvents([...seenStrangerEvents, strangerEv.id]);
      }

      // 7. 检查父母线 2-5 章
      const parentsEv = PARENTS_STORY.find(p => {
        if (p.chapter <= parentsChapter) return false; // 已通过的章节
        if (p.triggerType === 'after_call_home') return false; // 第 1 章是call_home后触发的
        if (newWeek < p.triggerWeek) return false;
        if (p.requireFlag && !flags[p.requireFlag]) return false;
        return true;
      });
      if (parentsEv) {
        setTimeout(() => {
          setActiveParentsChapter(parentsEv);
          audio.ding();
        }, 2400);
      }
    }

    // === 心理状态触发（每晚都检查） ===
    triggerNightState(newDay);

    setDay(newDay);
    setCurrentLocation(null);
  }

  // 检查夜间心理状态触发（梦境/失眠/思乡）
  function triggerNightState(newDay) {
    // 概率：5% 梦境，3% 失眠，由属性触发
    const r = Math.random();

    // 梦境：归属 < 35 + 至少第 4 周 + 8% 概率
    if (stats.belonging < 35 && week >= 4 && r < 0.08) {
      const available = DREAMS.filter(d => !seenDreams.includes(d.id));
      if (available.length > 0) {
        const dream = available[Math.floor(Math.random() * available.length)];
        setTimeout(() => {
          setActiveDream(dream);
          audio.message();
        }, 600);
        setSeenDreams([...seenDreams, dream.id]);
        return;
      }
    }

    // 失眠：精力 < 25 + 学业 > 55 (用力过猛)
    if (stats.energy < 25 && stats.academic > 55 && r < 0.12) {
      const available = INSOMNIA_THOUGHTS.filter(i => !seenInsomnia.includes(i.id));
      if (available.length > 0) {
        const ins = available[Math.floor(Math.random() * available.length)];
        setTimeout(() => {
          setActiveInsomnia(ins);
          audio.warning();
        }, 600);
        setSeenInsomnia([...seenInsomnia, ins.id]);
        return;
      }
    }
  }

  // 关闭梦境（不影响数值，只是体验）
  function dismissDream() {
    audio.click();
    setActiveDream(null);
  }

  // 关闭失眠 - 第二天精力 +5 但归属 -3
  function dismissInsomnia() {
    audio.click();
    setStats(s => ({
      ...s,
      energy: clamp(s.energy + 5, 0, 100),
      belonging: clamp(s.belonging - 3, 0, 100),
    }));
    setActiveInsomnia(null);
  }

  // 触发思乡（被节日/特殊事件主动触发，不是随机）
  function triggerNostalgia(triggerKey) {
    const moments = NOSTALGIA_MOMENTS.filter(m => m.trigger === triggerKey && !seenNostalgia.includes(m.id));
    if (moments.length > 0) {
      const m = moments[Math.floor(Math.random() * moments.length)];
      setActiveNostalgia(m);
      setSeenNostalgia([...seenNostalgia, m.id]);
      audio.message();
    }
  }

  function dismissNostalgia() {
    audio.click();
    const newBelonging = clamp(stats.belonging - 8, 0, 100);
    setStats(s => ({ ...s, belonging: newBelonging }));
    setFlags(f => ({ ...f, recent_nostalgia: true }));
    setActiveNostalgia(null);

    // 增加思乡计数 + 检查归属危机触发
    const newCount = nostalgiaCount + 1;
    setNostalgiaCount(newCount);

    // 触发条件：思乡 ≥ 3 次 + 归属 < 30 + 还没触发过
    if (newCount >= 3 && newBelonging < 30 && !crisisTriggered) {
      setTimeout(() => {
        setActiveCrisis({
          id: 'crisis_quit',
          title: '一个让你坐起来的念头',
          body: '凌晨 4:38。\n\n你睁眼看着天花板。\n\n你在伦敦已经待了 ' + week + ' 周。\n\n你想：\n\n如果我现在订机票回去呢？\n如果我不要这个学位呢？\n如果我承认这个事情我做不到呢？\n\n你想了 5 分钟。\n你想了 20 分钟。\n你拿起手机。'
        });
        setCrisisTriggered(true);
        audio.warning();
      }, 1000);
    }
  }

  // 处理归属危机选择
  function chooseCrisis(choice) {
    audio.click();
    if (choice.id === 'quit') {
      // 直接进入"中途回去"结局 - 根据关系动态生成
      setActiveCrisis(null);

      // 段落 1：决定订机票（固定）
      let text = '你订了 7 天后的机票。回程。\n\n你坐在床边 看着那张确认信。心跳得很慢。你以为做这个决定会很痛。但你只是觉得 安静。';

      // 段落 2：给爸妈打电话（固定）
      text += '\n\n— ⋅ —\n\n你给爸妈打了视频电话。\n\n妈妈以为你要告诉她什么坏消息。但你只是说："我想回家了。我读不下去了。"\n\n她沉默了 3 秒。然后说："那就回来。"\n\n爸爸在背景里："对 回来。我们家不缺这个学位。"\n\n你哭了。你说"对不起"。\n\n妈妈说："对不起什么。家是用来回的。"';

      // 段落 3：朋友们的消息（按关系出现）
      const messages = [];
      if ((npcRel.sarah || 0) >= 4) {
        messages.push('Sarah："Where are you?? You weren\'t in tutorial. Coffee tomorrow?"');
      }
      if ((npcRel.aditi || 0) >= 4) {
        messages.push('Aditi："I noticed you haven\'t been around. Are you ok?"');
      }
      if ((npcRel.wangkai || 0) >= 4) {
        messages.push('王凯："哥们/姐们 你最近怎么不来店里 出什么事了"');
      }
      if ((npcRel.whitmore || 0) >= 4) {
        messages.push('Whitmore："I missed you in supervision yesterday. Hope all is well."');
      }
      if ((npcRel.mei || 0) >= 4) {
        messages.push('Mei 姐："傻孩子 这两天没来吃饭啊"');
      }

      if (messages.length > 0) {
        text += '\n\n— ⋅ —\n\n你登机前打开手机。\n\n' + messages.join('\n') + '\n\n你看着这些消息看了很久。\n\n原来不是没人在意。\n\n你回了大家一句话："I\'m going home for a while. Take care."\n\n你不知道是为什么 但你没说"再也不回来了"。';
      } else {
        text += '\n\n— ⋅ —\n\n7 天里你删了几个 app 登录。退了图书馆账号。把房子转租出去。\n\n这一年你结识了一些人 但没有真正进入任何一个圈子。所以走得也没人发觉。';
      }

      // 段落 4：Mei 姐追到 Heathrow（如果关系 ≥6）
      if ((npcRel.mei || 0) >= 6) {
        text += '\n\n— ⋅ —\n\nHeathrow T3。你已经过了安检 在登机口。\n\n手机响了。Mei 姐："傻孩子 你看你身后。"\n\n你回头。\n\n她真的从 Croydon 坐了 1.5 小时地铁过来。她比你印象中老了一点 头发上有点白霜。她手里捧着一个保温杯。\n\n"刚煮的。让你飞机上喝。"\n\n你眼眶一下红了。你说"姐..."\n\n她打断你："叫姨。"\n\n你叫了。"姨。"\n\n她推你："快去 别误了飞机。" 但她自己也在哭。\n\n你们在 Heathrow T3 的 candy 店门口抱了 30 秒。\n\n你登机。保温杯打开是红枣枸杞汤。还热的。\n\n飞机起飞的时候你想：我在这个城市 至少有一个真正的家人。';
      }

      // 段落 5：尾声（固定）
      // 计算当前是哪个月（开学9月 = month 1）
      const monthNames = ['9月', '10月', '11月', '12月', '1月', '2月', '3月', '4月', '5月', '6月', '7月', '8月'];
      const monthIdx = Math.min(11, Math.floor((week - 1) / 4));
      const currentMonth = monthNames[monthIdx] || '某月';
      text += '\n\n— ⋅ —\n\n飞机起飞了。\n\n你看着舷窗外的伦敦慢慢变小。从你 9 月份来的那座你害怕的城市 变成你 ' + currentMonth + '份离开的这一座 你已经爱过又放下的城市。\n\n这不是失败。这只是你做了一个艰难但诚实的决定——比硬撑着读完一个让自己破碎的学位 要诚实。\n\n人生还很长。家是用来回的。';

      setEnding({
        title: '中途回去', subtitle: 'Going Home, Mid-Way',
        text: text,
      });
      setScreen('ending');
    } else if (choice.id === 'persist') {
      setStats(s => ({ ...s, energy: clamp(s.energy + 5, 0, 100), belonging: clamp(s.belonging + 8, 0, 100) }));
      setNostalgiaCount(0); // 重置
      setEventFeedback('你放下手机。\n\n你想：再坚持一周看看。\n\n你不知道这一周会发生什么。但你知道现在订机票，是 4:38 凌晨的决定，不是清醒的决定。\n\n你睡了。\n\n第二天醒来的时候，你没那么想走了。');
    } else if (choice.id === 'call_mom') {
      setStats(s => ({ ...s, energy: clamp(s.energy - 5, 0, 100), belonging: clamp(s.belonging + 20, 0, 100) }));
      setNostalgiaCount(0);
      setEventFeedback('你按了视频键。\n\n中国是中午 12:38。妈妈在做饭。\n\n你说："妈 我...我有点想家。"\n\n她没有惊慌。她只是看着你说："那就视频陪我做饭吧。" 然后她把手机架在台子上。\n\n你看着她炒菜 30 分钟。一个字没说。\n\n你听到锅铲碰到锅的声音。听到她跟你爸说"加点盐"。听到楼下有车开过。\n\n半小时后她说："吃饭了 你也去睡吧。"\n\n你说"嗯"。然后挂了。\n\n你睡了一个 8 个月以来最沉的觉。');
    }
  }

  function dismissCrisis() {
    audio.click();
    setActiveCrisis(null);
    setEventFeedback(null);
  }

  // 陌生人专属事件回复
  function chooseStrangerEventOption(choice) {
    audio.click();
    const eff = choice.effect;
    setStats(s => ({
      academic: clamp(s.academic + (eff.academic || 0), 0, 100),
      wallet: s.wallet + (eff.wallet || 0),
      energy: clamp(s.energy + (eff.energy || 0), 0, 100),
      belonging: clamp(s.belonging + (eff.belonging || 0), 0, 100),
    }));
    if (eff.flag) setFlags(f => ({ ...f, [eff.flag]: true }));
    setEventFeedback(choice.feedback);
  }

  function dismissStrangerEvent() {
    audio.click();
    setActiveStrangerEventModal(null);
    setEventFeedback(null);
  }

  // @你事件回复
  function replyAtYou(choice) {
    audio.click();
    const eff = choice.effect;
    setStats(s => ({
      academic: clamp(s.academic + (eff.academic || 0), 0, 100),
      wallet: s.wallet + (eff.wallet || 0),
      energy: clamp(s.energy + (eff.energy || 0), 0, 100),
      belonging: clamp(s.belonging + (eff.belonging || 0), 0, 100),
    }));
    if (eff.flag) setFlags(f => ({ ...f, [eff.flag]: true }));
    if (eff.npc) {
      setNpcRel(r => {
        const next = { ...r };
        Object.entries(eff.npc).forEach(([id, delta]) => { next[id] = (next[id] || 0) + delta; });
        return next;
      });
    }
    // 把@事件作为消息加入群聊（让玩家在群里能看到这段对话）
    const member = GROUP_MEMBERS.find(g => g.id === activeAtYouEvent.askerId)
                || STRANGERS.find(s => s.id === activeAtYouEvent.askerId);
    if (member) {
      setGroupChat(prev => [...prev, {
        from: activeAtYouEvent.askerId,
        text: activeAtYouEvent.askerMsg.replace('@你', '@你'),
        id: `at-${activeAtYouEvent.id}-q`,
        week,
        time: new Date().toLocaleTimeString().slice(0,5),
      }]);
    }
    setEventFeedback(choice.feedback);
  }

  function dismissAtYou() {
    audio.click();
    setActiveAtYouEvent(null);
    setEventFeedback(null);
  }

  // 触发生日事件
  function triggerBirthday() {
    const totalRel = (npcRel.sarah || 0) + (npcRel.aditi || 0) + (npcRel.wangkai || 0) + (npcRel.mei || 0);
    if (totalRel >= 12) {
      // 朋友给你过生日
      setActiveEvent({
        id: 'birthday_friends', tag: 'birthday',
        title: '🎂 你的生日',
        body: '你完全没跟人提过你生日。但下午 6 点，门铃响了。\n\n你打开门——Sarah、Aditi、王凯（如果关系够都来了）站在门口，捧着一个 Sainsbury\'s 蛋糕，齐声唱"Happy Birthday"。\n\nMei 姐还偷偷塞给 Sarah 一袋自己做的红烧肉。',
        choices: [
          { label: '哭出来', effect: { energy: 5, belonging: 25, npc: { sarah: 2, aditi: 2, wangkai: 2, mei: 2 } },
            feedback: '你哭着说"你们怎么知道的"。原来 Aditi 偷看过你的护照照片。Sarah 笑你眼泪鼻涕一起来。\n\n那一晚你们 4 个人在公寓里挤在沙发上看电影，吃外卖披萨。\n\n你想：第一年在异乡过生日，原来可以是这样的。' },
        ],
      });
      audio.ding();
    } else {
      // 自己一个人过
      setActiveEvent({
        id: 'birthday_alone', tag: 'birthday',
        title: '🎂 你的生日',
        body: '今天你生日。微信群里收到了 23 条祝福。室友不知道。',
        choices: [
          { label: '自己给自己买个蛋糕', effect: { wallet: -12, energy: 3, belonging: 2 },
            feedback: 'Sainsbury\'s 的小蛋糕，£8。你吹了蜡烛。许愿的时候想了想，没什么想许的。' },
          { label: '什么也不做', effect: { energy: -8, belonging: -8 },
            feedback: '你正常上了课，吃了泡面，睡了。直到第二天看到爸爸发的"生日快乐"，你才反应过来昨天发生了什么。' },
        ],
      });
      audio.ding();
    }
  }

  // 假期选择
  function chooseHoliday(choice) {
    audio.click();
    const eff = choice.effect;
    setStats(s => ({
      academic: clamp(s.academic + (eff.academic || 0), 0, 100),
      wallet: s.wallet + (eff.wallet || 0),
      energy: clamp(s.energy + (eff.energy || 0), 0, 100),
      belonging: clamp(s.belonging + (eff.belonging || 0), 0, 100),
    }));
    if (eff.flag) setFlags(f => ({ ...f, [eff.flag]: true }));
    // 隐藏剧情可能改 NPC 关系
    if (eff.rel) {
      setNpcRel(r => {
        const next = { ...r };
        Object.entries(eff.rel).forEach(([npcId, delta]) => {
          next[npcId] = (next[npcId] || 0) + delta;
        });
        return next;
      });
    }
    setEventFeedback(choice.feedback);
  }

  function dismissHoliday() {
    audio.click();
    if (showHolidayScreen === 'xmas') setHolidayChoice('xmas_done');
    if (showHolidayScreen === 'easter') setHolidayChoice('easter_done');
    setShowHolidayScreen(null);
    setEventFeedback(null);
  }

  // 考试完成
  function finishExam(score) {
    audio.click();
    if (score >= 70) audio.success(); else if (score >= 40) audio.click(); else audio.fail();
    setExamResults(r => ({ ...r, [activeExam.id]: score }));
    setStats(s => ({
      ...s,
      academic: clamp(s.academic + (score >= 70 ? 8 : score >= 50 ? 3 : -5), 0, 100),
      energy: clamp(s.energy - 15, 0, 100),
      belonging: clamp(s.belonging + (score >= 70 ? 4 : 0), 0, 100),
    }));
    setActiveExam(null);
  }

  // 选论文题目
  function chooseDissertationTopic(topic) {
    audio.click();
    setDissertationTopic(topic);
    const eff = topic.effect;
    setStats(s => ({
      academic: clamp(s.academic + (eff.academic || 0), 0, 100),
      wallet: s.wallet + (eff.wallet || 0),
      energy: clamp(s.energy + (eff.energy || 0), 0, 100),
      belonging: clamp(s.belonging + (eff.belonging || 0), 0, 100),
    }));
    if (topic.flag) setFlags(f => ({ ...f, [topic.flag]: true }));
    setEventFeedback(topic.feedback);
  }

  function dismissDissertationTopic() {
    audio.click();
    setShowDissertationTopicScreen(false);
    setEventFeedback(null);
  }

  // 写论文（论文季的特殊行动）
  function writeDissertation() {
    if (actionsLeft <= 0) return;
    audio.click();
    setActionsLeft(actionsLeft - 1);
    const progress = dissertationTopic?.id === 'ambitious' ? 4 : dissertationTopic?.id === 'personal' ? 5 : 6;
    setDissertationProgress(p => Math.min(100, p + progress));
    setStats(s => ({
      ...s,
      energy: clamp(s.energy - 12, 0, 100),
      academic: clamp(s.academic + 2, 0, 100),
    }));
    setCurrentLocation(null);
  }

  function generateEnding() {
    const s = stats;
    const sp = storyProgress;
    const f = flags;

    // ========================================
    // 等级 0：父母来过 + 学业不错 = 这游戏最重的结局
    // ========================================
    if (f.parents_visited && s.academic >= 55) {
      setEnding({ title: '我让他们看到了', subtitle: 'What They Saw',
        text: '毕业典礼那天，爸妈又来了。\n\n这次他们不再怯生生的。他们坐在你旁边，跟周围的英国家长点头微笑。妈妈穿了一件你以前没见过的红色外套。爸爸打了领带——他这辈子领带次数没超过 5 次。\n\n你穿学袍走过台子的时候，听到台下传来一声不太响但很穿透的"哎哎哎"——是你妈，她不知道毕业典礼不能喊。\n\n你没回头。但你笑了。\n\n爸爸把你穿学袍的照片发到了家族群。你姑妈秒回："这孩子有出息了。" 你姑父："恭喜恭喜。"\n\n你爸罕见地回了一句话——比他过去一年发的所有朋友圈加起来都长：\n\n"不是这孩子有出息了。是这孩子让我和她妈这一辈子值了。"\n\n群里安静了 30 秒。\n\n然后你妈妈发了一句："老头子。煽什么情。" 后面跟了一个 doge 表情。\n\n你看着这条消息看了 5 分钟。然后你笑了。然后你哭了。\n\n你想起一年前你在 Heathrow T3 接他们时妈妈手里那袋你 8 岁时最爱吃的饼干。\n\n你想起你爸抚摸学校牌匾时偷偷擦的那滴泪。\n\n你想起他说"对不起 这一年让你一个人"。\n\n你心里说：爸 不是你对不起我。是你给了我这一年。\n\n谢谢你们。' });
      setScreen('ending'); return;
    }

    // ========================================
    // 等级 1：双重隐藏剧情组合结局（最稀有）
    // ========================================

    // 圣诞 Sarah + 复活节 Sarah → Sarah 终极线
    if (f.cotswolds_xmas && f.eurotrip_sarah) {
      setEnding({ title: '一辈子的朋友', subtitle: "Sarah's Best Mate",
        text: '毕业三年后。你回伦敦参加 Sarah 的婚礼。\n\n她穿着一身简单的白裙，在 Cotswolds 那栋你过过圣诞的房子里。她妈把你当自家孩子一样抱了一下："Welcome home, dear."\n\n仪式上 Sarah 念誓词的时候转过头看了你一眼，笑了。后来婚礼录像里你看到那一秒——她笑着对你眨了眨眼，像在说"你看，我们做到了"。\n\n你在伴娘/伴郎致辞里说：「I came to England not knowing anyone. Sarah taught me what it meant to have a friend here. And now her family is my family.」\n\nSarah 哭了。她妈也哭了。整个 Cotswolds 都哭了。\n\n你想起那个第一次去 Pub 不敢点酒的自己，觉得他离这里好远。' });
      setScreen('ending'); return;
    }

    // Aditi 印度 + 复活节 Aditi → Aditi 双线
    if (f.visited_india && f.easter_aditi_pact) {
      setEnding({ title: '一封孟买来的信', subtitle: 'Letter from Mumbai',
        text: '毕业一年后。你在多伦多工作。一个寻常的周二，你收到一封手写的信。\n\nAditi 用了印度邮票，蓝色的航空信封。她写：\n\n"Dad passed last month. He held on for a long time, and I think a part of why he did was because he wanted to thank you again, in person. He didn\'t get to. But he wanted you to know.\n\nI got engaged. His name is Vikram. He works in Bangalore. The wedding is in March. I want you to come.\n\nDo you remember what you said in the library at 2am? \'You have me.\' I remembered that every day this year. Now it\'s my turn.\n\nYou have me. Always.\n\n— A."\n\n你坐在多伦多的小公寓里读了三遍。\n\n然后你订了去孟买的机票。' });
      setScreen('ending'); return;
    }

    // Mei 一家 + 复活节当经理 → Mei 终极线
    if (f.mei_family && f.mei_manager) {
      setEnding({ title: 'Lucky Star 的少东家', subtitle: "Auntie's Heir",
        text: '毕业那天 Mei 姐没去你的毕业典礼。"姨忙着开第二家店呢。"\n\n第二家店开在 Camden。你帮她设计了菜单，做了 logo，谈下了房租。开业那天 Mei 姐让你站在她旁边剪彩。\n\n她说："我儿子不学这行，他们要做 software engineer。" 然后她把一份合同推到你面前。"30% 干股。你管伦敦扩张。我管福建货源。"\n\n你看着她。她说："傻孩子哭什么。"\n\n你说："姨..."\n\n她说："叫姨我就给你 35%。"\n\n5 年后 Lucky Star 在伦敦有 7 家店。Mei 姐成了你婚礼上的证婚人。她在台上说："这孩子第一次走进我店里的时候，瘦得跟根筷子似的..." 你笑着哭了。' });
      setScreen('ending'); return;
    }

    // Whitmore 圣诞晚宴 + 复活节论文 → Whitmore 双线
    if (f.high_table && f.thesis_polished) {
      setEnding({ title: '《剑桥评论》的作者', subtitle: 'A Voice in Print',
        text: '8 月。你的论文不仅拿了 Distinction，还被 *Cambridge Review of Cultural Studies* 接收发表。\n\n这是你专业领域里全英最权威的期刊之一。审稿人留言："Original thinking. A fresh voice. Recommended for publication with minor revisions."\n\nWhitmore 把样刊递给你的时候手有点抖。"读读看吧。"\n\n你翻到你的文章。作者署名后面的"University of London" 让你愣了 5 秒。\n\n他说："你不再是那个不敢举手的孩子了。" 你看着他，第一次发现他眼睛是浅蓝色的。\n\n临走时他说："我退休了。九月。" 你说："Sir—"\n\n他打断你："Don\'t \'sir\' me anymore. Call me James."\n\n你叫不出口。你只是用力地握了握他的手。' });
      setScreen('ending'); return;
    }

    // 王凯爆肝圣诞 + 学徒复活节 → 王凯双线
    if (f.xmas_grind && f.wangkai_apprentice) {
      setEnding({ title: '"哥们 仗义"', subtitle: 'Brothers in Bubble Tea',
        text: '王凯本来想自己回国搞奶茶。后来他改主意了。"哥们 你跟我一起。"\n\n你们俩 8 月毕业，9 月就开了 Lucky Tea 第一家。10 月开第二家。半年开 8 家。\n\n你管运营，他管供应链。你说英文，他说潮州话。你写 BP，他撒酒疯。你们吵过架，差点散伙过两次。但每次都和好。\n\n3 年后 Lucky Tea 在英国 32 家店，估值 £8M。你们俩上了《福布斯 30 under 30》。\n\n采访那天记者问你们："是什么让你们成功？" 王凯叼着烟说："命好。"\n\n记者笑了，转向你。你想了想，说："是那个 2024 年的圣诞，他扔给我 £2500 现金那个晚上。我那时候才 22 岁，那是我第一次觉得，自己也算个人物了。"\n\n王凯听了，把烟摁灭了。然后说："滚。" 但你看到他眼睛红了。' });
      setScreen('ending'); return;
    }

    // ========================================
    // 等级 2：单 NPC 延伸结局
    // ========================================

    // Sarah · Cotswolds 永久之家
    if (f.cotswolds_xmas) {
      setEnding({ title: 'Cotswolds 的窗', subtitle: 'A Window in the Hills',
        text: '毕业后你搬去了 Cotswolds 附近的一个小镇，因为伦敦房租太贵。\n\nSarah 家离你 20 分钟车程。每个周日你去他们家蹭饭。她妈坚持每周给你打包冷冻 stuffing 让你带回去。\n\n你写远程文案为生，工资不高，但够生活。Sarah 在牛津读 PhD，每隔一周回家一次，你们一起去镇上的 pub。\n\n圣诞那天，Sarah 妈做完 turkey 之后说："我想问问你的妈妈，今年要不要也飞过来过节？我想认识她。"\n\n你愣了。然后哭了。\n\n两个月后，你妈来了 Cotswolds。她不会英语，Sarah 妈不会中文。她们两个站在厨房里，比着手势教对方做饺子和 Yorkshire pudding。你和 Sarah 站在门口看着，没说话。\n\n这就是家。' });
      setScreen('ending'); return;
    }

    // Aditi · 印度的春天
    if (f.visited_india) {
      setEnding({ title: '印度的春天', subtitle: 'Spring in Mumbai',
        text: '毕业后你做了一个决定——去孟买待半年。\n\nAditi 给你介绍了她大学的导师，你做客座研究员，免费住她家。她爸爸虽然瘦了，但精神好多了。每天早上他给你做 chai，问你"How are you, beta?" beta 是孩子的意思。\n\n半年里你学会了说一点 Hindi，你学会了用手吃咖喱，你学会了在 35 度的阳台上读论文。\n\nAditi 妈妈给你一个金色的护身符，说"This is for safe travels." 你戴着它回了伦敦，然后又回了中国。它现在挂在你的钥匙圈上。\n\n你从来不是一个会去印度的人。但你成了那个去过印度的人。\n\n所以你也可以成为别的什么人。这就是 Aditi 教会你的事。' });
      setScreen('ending'); return;
    }

    // Mei 姐 · 家
    if (f.mei_family) {
      setEnding({ title: '叫一声"姨"', subtitle: 'Calling Her "Auntie"',
        text: '毕业后你在 Mei 姐家住了三个月。她小儿子的房间——他去寄宿学校了。\n\n你早上 7 点起来帮 Mei 姐去 New Covent Garden 进货。下午在店里端盘子。晚上回家陪她和她老公吃饭。她老公话很少，但每次你回家都会问一句"今天累不累"。\n\n你慢慢明白 Mei 姐为什么对你这么好——你长得有点像她妹妹的孩子，30 年前没能来英国和她团聚的那个表妹/表弟。\n\n你没有再叫她"Mei 姐"。你叫她"姨"。\n\n姨。\n\n这一个字，是你来英国之后，最难学会、也最珍贵的一个字。' });
      setScreen('ending'); return;
    }

    // Whitmore · High Table
    if (f.high_table) {
      setEnding({ title: '坐到桌子那头', subtitle: 'A Seat at the Table',
        text: '毕业三年后你回到这所大学——做了 Whitmore 的同事。年轻 lecturer，三年合同。\n\n第一次 College High Table dinner 你坐在他对面。Lord Kerridge 还在，认出你了："Ah, you\'re the one with the joke about Hegel!" 全桌笑。\n\n席间你听他们辩论了 3 小时。这一次你不再是听众。你说了 5 次话，每次都有人接你的话。Whitmore 在旁边假装没看你，但你知道他在偷偷笑。\n\n席散时你们走出 quad。雪刚下。他说："Welcome to the table, my friend."\n\n你说："Thank you, James."\n\n他终于笑出声。' });
      setScreen('ending'); return;
    }

    // 王凯 · 创业新生
    if (f.xmas_grind || f.wangkai_apprentice) {
      setEnding({ title: '£2500 的那个晚上', subtitle: 'The £2500 Night',
        text: '毕业后你没回国，也没找正经工作。\n\n你跟王凯合开了一家小奶茶店。第一年艰难得要命——你们俩睡店里，吃外卖剩饭，瘦得像两根麻杆。但第二年开了第二家。第三年第五家。\n\n爸妈一开始不理解，后来看到你寄回家的钱，慢慢闭嘴了。\n\n你和王凯之间有一个秘密——那个 2024 年圣诞，他扔给你 £2500 现金的那个晚上，你们俩抱头痛哭了。两个 24 岁的大男人/男生女生在凌晨 4 点的奶茶店里，黑眼圈下到颧骨，傻笑着哭。\n\n那一晚你们决定，这辈子要做出点什么。\n\n你做出来了。' });
      setScreen('ending'); return;
    }

    // 复活节欧洲穷游 (单)
    if (f.eurotrip_sarah) {
      setEnding({ title: '5 个国家的春天', subtitle: 'Spring in Five Countries',
        text: '那 21 天的欧洲穷游成了你和 Sarah 之间的一个永久的私人语言。\n\n5 年后她结婚了，新郎不是你。你们没在一起过，从来不会，你们都知道。\n\n但每年 4 月，无论你们身在何处，她都会发来一张照片：可能是巴黎的某个咖啡馆，可能是雅典 Acropolis 的夕阳，可能是米兰大教堂的鸽子。\n\n配文永远只有四个字母："I miss."\n\n你也永远回同样的字："Me too."\n\n这是有些朋友才有的特权。这是有些春天才会留下的东西。' });
      setScreen('ending'); return;
    }

    // 复活节 Aditi pact (单)
    if (f.easter_aditi_pact) {
      setEnding({ title: '把彼此变好的人', subtitle: 'Made Each Other Better',
        text: '毕业后 Aditi 回了 Bangalore，你回了北京/上海。\n\n但你们的 7am pact 没停。每天早上 7 点（北京时间）/ 4:30 (Bangalore)，你们俩同时开 zoom，互相督促健身、写作、读书。这个习惯持续了 6 年。\n\n6 年里你们都升职了，都瘦了，都读了 100 多本书。你们见证了对方的恋爱、分手、再恋爱。\n\nAditi 后来说，她爸爸去世前最后几句话之一是："Tell your friend I said thank you." 你哭了一个下午。\n\n世界上最好的友谊不是热烈的，是长久的。是那种 6 年风雨无阻的、4:30 的 zoom 通话。\n\n是那种，"You have me. Always."' });
      setScreen('ending'); return;
    }

    // ========================================
    // 等级 3：原有的稀有结局
    // ========================================

    if (f.oxford_ref && s.academic >= 70) {
      setEnding({ title: '牛津的录取信', subtitle: 'The Oxford Letter',
        text: '4 月。一封 DPhil offer 躺在你的邮箱里。Christ Church 给的全奖。\n\n你想起一年前坐在 Heathrow 的样子——什么都不懂，什么都怕。\n\n你打开 Whitmore 的邮件回他："Thank you. I don\'t know how to thank you." 他回了三个字："Earn it."\n\n你在伦敦的 flat 里坐了很久。你来留学的所有理由——证明给爸妈看，证明给前男友/女友看，证明给那个自己看——都已经不重要了。\n\n你只是想知道更多。这就够了。' });
      setScreen('ending'); return;
    }
    if (f.returned_with_wk) {
      setEnding({ title: '回去创业', subtitle: 'The Bet',
        text: '你跟王凯回了国。第一年开了 3 家奶茶店。第二年扩到 12 家。第三年——你不知道。\n\n但你父母再也不催你"找份稳定的工作"了。你妈在朋友圈发你的店开业的照片，配文"我儿子/女儿在创业"。\n\n伦敦的两年好像一场梦。你偶尔会想念 Sarah，想念 Aditi，想念图书馆 4 楼。\n\n但你不后悔。这次是你自己选的路。' });
      setScreen('ending'); return;
    }
    if (sp.aditi >= 5 && sp.sarah >= 4) {
      setEnding({ title: '我的人在异乡', subtitle: 'My People',
        text: '毕业典礼那天 Sarah 哭了，你也哭了。Aditi 视频连线进来，三个人挤在一个小小的屏幕里傻笑。\n\n你拍了一张照片发到家族群。妈妈问"这两个女孩/男孩是谁？"\n\n你回："这是我朋友。"\n\n这五个字在你嘴里转了一年，今天才终于说得出口。' });
      setScreen('ending'); return;
    }
    if (sp.mei >= 3 && s.belonging >= 50) {
      setEnding({ title: '留在 Mei 姐身边', subtitle: 'Family',
        text: '毕业后你没回国。你在 Mei 姐的中餐馆做了一年。她让你管点单系统，你帮她改了菜单，加了一行小字"Welcome home."\n\n你妈一开始不理解："读了这么多书去端盘子？"\n\n但你知道你在做什么。你在还债——还给那个第一次走进 Mei\'s 的、孤单到差点崩溃的自己。你想让别的孩子也有这样一个地方可去。' });
      setScreen('ending'); return;
    }

    // ========================================
    // 等级 4：通用结局
    // ========================================

    if (s.belonging >= 60 && s.academic >= 55) {
      setEnding({ title: '找到自己', subtitle: 'Becoming',
        text: '毕业典礼那天下着小雨。你穿着学袍，在 quad 里和朋友们拍照——他们来自六个不同的国家。\n\n你没有变成一个"英国人"，也没有变回出国前的那个你。你成了一个新的人。\n\n你不知道接下来去哪里。但第一次，你不害怕。' });
    } else if (s.belonging < 25) {
      setEnding({ title: '麻木地毕业', subtitle: 'Graduated',
        text: '你毕业了。GPA 还不错。简历可以加一行 "MSc, [University]"。\n\n但你想不起来上一次真正笑出声是什么时候。你的英国手机号马上要停了，朋友圈三个月没更新。\n\n你以为留学会改变你。回过头看，它只是把你压扁了一点，又让你站起来继续走。' });
    } else if (s.wallet >= 1500 && s.belonging < 45) {
      setEnding({ title: '打工人', subtitle: 'Survivor',
        text: '你毕业的时候存款比来的时候还多。你在中餐馆、奶茶店、代购、家教之间来回切换。\n\n你的英语进步很慢，因为你说得最多的是"哥要不要加波霸"。\n\n但你不后悔。你证明了自己可以靠自己活下来。' });
    } else {
      setEnding({ title: '留下来', subtitle: 'Staying',
        text: '你申请了毕业生工签，签证批了。你找了一份不算理想但能糊口的工作，搬到了 zone 4 一个更便宜的房子。\n\n你成了那种"已经在英国五年了"的人——朋友圈里偶尔出现，过年的时候微信群里说"今年又不回了"。\n\n你已经是一个永久的异乡人。这不是失败，也不是胜利。这只是，你的人生现在的样子。' });
    }
    setScreen('ending');
  }

  // 旅行
  function startTravel(dest) {
    audio.click();
    if (stats.wallet < dest.cost) return;
    setStats(s => ({ ...s, wallet: s.wallet - dest.cost }));
    setTravelMode({ destination: dest, daysLeft: dest.days });
    setTravelDayUsed(0);
    setCurrentLocation(null);
    setScreen('travel');
  }

  function chooseTravelEvent(ev) {
    audio.click();
    setActiveTravelEvent(ev);
  }

  function completeTravelEvent(choice) {
    audio.click();
    const eff = choice.effect;
    setStats(s => ({
      academic: clamp(s.academic + (eff.academic || 0), 0, 100),
      wallet: s.wallet + (eff.wallet || 0),
      energy: clamp(s.energy + (eff.energy || 0), 0, 100),
      belonging: clamp(s.belonging + (eff.belonging || 0), 0, 100),
    }));
    if (eff.flag) setFlags(f => ({ ...f, [eff.flag]: true }));

    // 收集明信片
    if (activeTravelEvent.postcard) {
      setPostcards(p => {
        if (p.find(card => card.id === activeTravelEvent.id)) return p;
        return [...p, { id: activeTravelEvent.id, city: travelMode.destination.id,
                         text: activeTravelEvent.postcard, day }];
      });
    }

    // 标记事件已看
    setTravelEventsSeen(s => ({
      ...s,
      [travelMode.destination.id]: [...(s[travelMode.destination.id] || []), activeTravelEvent.id],
    }));

    setEventFeedback(choice.feedback);
  }

  function dismissTravelEvent() {
    audio.click();
    setActiveTravelEvent(null);
    setEventFeedback(null);

    // 推进旅行的一天
    const newDayUsed = travelDayUsed + 1;
    if (newDayUsed >= travelMode.destination.days) {
      // 旅行结束
      finishTravel();
    } else {
      setTravelDayUsed(newDayUsed);
    }
  }

  function skipTravelDay() {
    audio.click();
    const newDayUsed = travelDayUsed + 1;
    if (newDayUsed >= travelMode.destination.days) {
      finishTravel();
    } else {
      setTravelDayUsed(newDayUsed);
    }
  }

  function finishTravel() {
    audio.click();
    // 推进游戏内时间
    const daysSpent = travelMode.destination.days;
    const newDay = day + daysSpent;
    setDay(Math.min(newDay, TOTAL_DAYS));
    setTravelMode(null);
    setTravelDayUsed(0);
    setActiveTravelEvent(null);
    setEventFeedback(null);
    setActionsLeft(DAILY_ACTIONS);
    setStats(s => ({ ...s, energy: clamp(s.energy + 5, 0, 100) }));
    setScreen('playing');
  }

  function restart() {
    audio.click();
    setScreen('intro');
    setDay(1); setStats({ academic: 30, wallet: 800, energy: 80, belonging: 20 });
    setNpcRel({ sarah: 0, wangkai: 0, aditi: 0, whitmore: 0, mei: 0 });
    setStoryProgress({ sarah: 0, mei: 0, wangkai: 0, aditi: 0, whitmore: 0 });
    setFlags({}); setSeenLocationEvents({}); setMessages([]); setUnreadMessages(0);
    setCurrentLocation(null); setActiveEvent(null); setActiveStoryChapter(null);
    setActiveNpcDialog(null); setEventFeedback(null);
    setActionsLeft(DAILY_ACTIONS);
    setSeenChapters([]); setAttendanceHistory([]);
    setClassesAttendedThisWeek(0); setEnding(null);
    setHolidayChoice(null); setShowHolidayScreen(null);
    setActiveExam(null); setExamResults({});
    setDissertationProgress(0); setDissertationTopic(null);
    setShowDissertationTopicScreen(false); setMonthAttendance([]);
    setTravelMode(null); setTravelEventsSeen({}); setPostcards([]);
    setTravelDayUsed(0); setActiveTravelEvent(null);
    setWeekWeather({}); setSeenFestivals([]); setSeenWeatherEvents([]);
    setGroupChat([]); setSeenGroupWeeks([]); setUnreadGroup(0);
    setActiveMinigamePret(false); setActiveMinigameEssay(false); setActiveMinigameMatch(false);
    setBirthdayMonth(null); setShowBirthdayPrompt(false); setBirthdayCelebrated(false);
    setAddedStrangers([]); setActiveStrangerEvent(null);
    setSeenAtYouEvents([]); setActiveAtYouEvent(null);
    setActiveDream(null); setSeenDreams([]);
    setActiveInsomnia(null); setSeenInsomnia([]);
    setActiveNostalgia(null); setSeenNostalgia([]);
    setStrangerAddedAt({}); setSeenStrangerEvents([]); setActiveStrangerEventModal(null);
    setNostalgiaCount(0); setActiveCrisis(null); setCrisisTriggered(false);
    setParentsChapter(0); setActiveParentsChapter(null); setParentsCallTrigger(false);
  }

  return (
    <div className="min-h-screen w-full" style={{
      background: 'linear-gradient(180deg, #2a2520 0%, #1a1612 100%)',
      fontFamily: '"EB Garamond", "Songti SC", "Source Han Serif", serif',
      color: '#e8e0d0',
    }}>
      <div className="fixed inset-0 pointer-events-none opacity-15" style={{
        backgroundImage: `url("data:image/svg+xml,%3Csvg viewBox='0 0 200 200' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.9'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23n)' opacity='0.4'/%3E%3C/svg%3E")`,
        zIndex: 1,
      }} />
      <button onClick={() => setMuted(!muted)}
        className="fixed top-3 right-3 z-30 w-9 h-9 border border-current/40 bg-[#1a1612]/80 hover:border-current/80 flex items-center justify-center text-sm">
        {muted ? '🔇' : '🔊'}
      </button>

      {showStoryNotification && (
        <div className="fixed top-4 left-1/2 -translate-x-1/2 z-50 px-6 py-3 border border-amber-300/60 bg-[#1a1612]/95 animate-fadein-slow">
          <div className="text-xs tracking-[0.3em] opacity-60" style={{ fontFamily: 'monospace' }}>STORY ADVANCED</div>
          <div className="text-sm mt-1">{showStoryNotification}</div>
        </div>
      )}

      <div className="relative max-w-3xl mx-auto px-3 py-6" style={{ zIndex: 2 }}>
        {screen === 'intro' && <IntroScreen onStart={startGame} />}
        {screen === 'playing' && (
          <PlayingScreen
            day={day} week={week} dayOfWeek={dayOfWeek} stats={stats} actionsLeft={actionsLeft}
            weekInfo={weekInfo}
            tab={tab} setTab={setTab}
            currentLocation={currentLocation} setCurrentLocation={(l) => { audio.click(); setCurrentLocation(l); }}
            onGoToLocation={goToLocation}
            onAttendClass={attendClass} onWorkShift={workShift} onRestAtFlat={restAtFlat} onCallHome={callHome}
            onTalkNPC={talkToNPC}
            onWriteDissertation={writeDissertation}
            dissertationProgress={dissertationProgress}
            dissertationTopic={dissertationTopic}
            onEndDay={endDay}
            messages={messages} unreadMessages={unreadMessages} onReadMessages={() => setUnreadMessages(0)}
            npcRel={npcRel}
            attendanceRate={attendanceRate}
            currentMonthRate={currentMonthRate}
            classesAttendedThisWeek={classesAttendedThisWeek}
            storyProgress={storyProgress}
            travelMode={travelMode}
            onStartTravel={startTravel}
            monthAttendance={monthAttendance}
            examResults={examResults}
            weather={weekWeather[week]}
            groupChat={groupChat}
            unreadGroup={unreadGroup}
            onReadGroup={() => setUnreadGroup(0)}
            addedStrangers={addedStrangers}
            seenDreams={seenDreams}
            seenInsomnia={seenInsomnia}
            seenNostalgia={seenNostalgia}
            parentsChapter={parentsChapter}
            flags={flags}
            onTriggerPret={() => setActiveMinigamePret(true)}
            onTriggerEssay={() => setActiveMinigameEssay(true)}
            onTriggerMatch={() => setActiveMinigameMatch(true)}
          />
        )}

        {activeEvent && !activeEvent.minigame && (
          <EventModal event={activeEvent} feedback={eventFeedback}
            onChoose={chooseEventOption} onDismiss={dismissEvent} />
        )}
        {activeEvent && activeEvent.minigame === 'yellow_grab' && (
          <YellowLabelMinigame onComplete={(result) => {
            audio.click();
            if (result.success) audio.success(); else audio.fail();
            setStats(s => ({
              ...s, wallet: s.wallet - result.cost,
              energy: clamp(s.energy + result.energy, 0, 100),
              belonging: clamp(s.belonging + result.belonging, 0, 100),
            }));
            setEventFeedback(result.feedback);
          }} feedback={eventFeedback} onDismiss={dismissEvent} />
        )}
        {activeStoryChapter && (
          <StoryModal chapter={activeStoryChapter.chapter} lineName={STORYLINES[activeStoryChapter.lineId].name}
            feedback={eventFeedback} onChoose={chooseStoryOption} onDismiss={dismissEvent} />
        )}
        {activeNpcDialog && (
          <NpcDialogModal npc={activeNpcDialog} rel={npcRel[activeNpcDialog.id] || 0}
            feedback={eventFeedback} onChoose={chooseNpcTopic} onDismiss={dismissNpcDialog} />
        )}
        {showHolidayScreen && (
          <HolidayScreen type={showHolidayScreen}
            choices={showHolidayScreen === 'xmas' ? HOLIDAY_CHOICES_XMAS : HOLIDAY_CHOICES_EASTER}
            secrets={showHolidayScreen === 'xmas' ? HOLIDAY_SECRETS_XMAS : HOLIDAY_SECRETS_EASTER}
            stats={stats} npcRel={npcRel} storyProgress={storyProgress} flags={flags}
            feedback={eventFeedback} onChoose={chooseHoliday} onDismiss={dismissHoliday} />
        )}
        {activeExam && (
          <ExamScreen exam={activeExam} academic={stats.academic} onFinish={finishExam} />
        )}
        {showBirthdayPrompt && <BirthdayPromptScreen onSelect={setBirthdayAndStart} />}
        {activeStrangerEvent && (
          <StrangerEncounterModal stranger={activeStrangerEvent}
            onAdd={addStranger} onReject={rejectStranger} />
        )}
        {activeAtYouEvent && (
          <AtYouModal event={activeAtYouEvent}
            members={GROUP_MEMBERS} strangers={STRANGERS}
            feedback={eventFeedback}
            onChoose={replyAtYou} onDismiss={dismissAtYou} />
        )}
        {activeDream && <DreamModal dream={activeDream} onDismiss={dismissDream} />}
        {activeInsomnia && <InsomniaModal thought={activeInsomnia} onDismiss={dismissInsomnia} />}
        {activeNostalgia && <NostalgiaModal moment={activeNostalgia} onDismiss={dismissNostalgia} />}
        {activeStrangerEventModal && (
          <StrangerEventModal event={activeStrangerEventModal} strangers={STRANGERS}
            feedback={eventFeedback}
            onChoose={chooseStrangerEventOption}
            onDismiss={dismissStrangerEvent} />
        )}
        {activeParentsChapter && (
          <ParentsChapterModal chapter={activeParentsChapter}
            feedback={eventFeedback}
            onChoose={chooseParentsChapter}
            onDismiss={dismissParentsChapter} />
        )}
        {activeCrisis && (
          <CrisisModal crisis={activeCrisis} feedback={eventFeedback}
            onChoose={chooseCrisis} onDismiss={dismissCrisis} />
        )}
        {activeMinigamePret && (
          <PretMinigame
            onComplete={(result) => {
              audio.click();
              setStats(s => ({
                academic: s.academic, wallet: s.wallet + (result.effect.wallet || 0),
                energy: clamp(s.energy + (result.effect.energy || 0), 0, 100),
                belonging: clamp(s.belonging + (result.effect.belonging || 0), 0, 100),
              }));
              setEventFeedback(result.feedback);
              setActiveMinigamePret(false);
              setActiveEvent({ id: 'pret_done', title: '☕ Pret', body: '', choices: [] });
              setActiveEvent(null);
              setCurrentLocation(null);
              // 直接弹个事件展示反馈
              setActiveEvent({
                id: 'pret_result', title: '走出 Pret',
                body: result.feedback,
                choices: [{ label: '回去', effect: {}, feedback: '...' }],
              });
            }}
            onCancel={() => { audio.click(); setActiveMinigamePret(false); }}
          />
        )}
        {activeMinigameEssay && (
          <EssayMinigame
            onComplete={(result) => {
              audio.click();
              setStats(s => ({
                academic: clamp(s.academic + (result.effect.academic || 0), 0, 100),
                wallet: s.wallet,
                energy: clamp(s.energy + (result.effect.energy || 0), 0, 100),
                belonging: clamp(s.belonging + (result.effect.belonging || 0), 0, 100),
              }));
              setDissertationProgress(p => Math.min(100, p + result.score * 8));
              setActiveMinigameEssay(false);
              setActiveEvent({
                id: 'essay_result', title: '📝 写完一段',
                body: result.feedback,
                choices: [{ label: '继续', effect: {}, feedback: '...' }],
              });
            }}
            onCancel={() => { audio.click(); setActiveMinigameEssay(false); }}
          />
        )}
        {activeMinigameMatch && (
          <MatchMinigame
            onComplete={(result) => {
              audio.click();
              setStats(s => ({
                academic: clamp(s.academic + (result.effect.academic || 0), 0, 100),
                wallet: s.wallet,
                energy: clamp(s.energy + (result.effect.energy || 0), 0, 100),
                belonging: clamp(s.belonging + (result.effect.belonging || 0), 0, 100),
              }));
              setActiveMinigameMatch(false);
              setActiveEvent({
                id: 'match_result', title: '🎴 复习卡牌',
                body: result.feedback,
                choices: [{ label: '收起卡牌', effect: {}, feedback: '...' }],
              });
            }}
            onCancel={() => { audio.click(); setActiveMinigameMatch(false); }}
          />
        )}
        {showDissertationTopicScreen && (
          <DissertationTopicScreen
            feedback={eventFeedback}
            onChoose={chooseDissertationTopic}
            onDismiss={dismissDissertationTopic} />
        )}
        {screen === 'travel' && travelMode && (
          <TravelScreen
            destination={travelMode.destination}
            daysLeft={travelMode.destination.days - travelDayUsed}
            totalDays={travelMode.destination.days}
            events={(TRAVEL_EVENTS[travelMode.destination.id] || []).filter(
              e => !(travelEventsSeen[travelMode.destination.id] || []).includes(e.id)
            )}
            allEvents={TRAVEL_EVENTS[travelMode.destination.id] || []}
            seenEvents={travelEventsSeen[travelMode.destination.id] || []}
            stats={stats}
            onChooseEvent={chooseTravelEvent}
            onSkipDay={skipTravelDay}
            onFinish={finishTravel}
          />
        )}
        {activeTravelEvent && (
          <TravelEventModal event={activeTravelEvent}
            feedback={eventFeedback}
            onChoose={completeTravelEvent}
            onDismiss={dismissTravelEvent} />
        )}
        {screen === 'ending' && ending && <EndingScreen ending={ending} stats={stats} npcRel={npcRel}
          attendanceRate={attendanceRate} storyProgress={storyProgress}
          examResults={examResults} dissertationProgress={dissertationProgress}
          postcards={postcards}
          flags={flags} addedStrangers={addedStrangers}
          onRestart={restart} />}
      </div>
      <style>{`
        @keyframes fadein { from { opacity: 0; transform: translateY(8px); } to { opacity: 1; transform: translateY(0); } }
        @keyframes fadein-slow { from { opacity: 0; transform: translateY(20px); } to { opacity: 1; transform: translateY(0); } }
        @keyframes slidein { from { opacity: 0; transform: translateX(-10px); } to { opacity: 1; transform: translateX(0); } }
        .animate-fadein { animation: fadein 0.5s ease-out; }
        .animate-fadein-slow { animation: fadein-slow 0.8s ease-out; }
        .animate-slidein { animation: slidein 0.4s ease-out; }
      `}</style>
    </div>
  );
}

function IntroScreen({ onStart }) {
  return (
    <div className="text-center pt-12 pb-8 animate-fadein">
      <div className="text-xs tracking-[0.4em] opacity-50 mb-6" style={{ fontFamily: 'monospace' }}>A STUDY ABROAD RPG · V10</div>
      <h1 className="text-7xl font-light mb-2" style={{ letterSpacing: '0.05em' }}>異 鄉</h1>
      <div className="text-sm tracking-[0.3em] opacity-60 mb-12 italic">somewhere else</div>
      <div className="max-w-md mx-auto text-left space-y-3 text-sm leading-relaxed opacity-85" style={{ lineHeight: '1.9' }}>
        <p>九月，伦敦。两个箱子，一张录取通知书。</p>
        <p>52 周。10 个地点。5 个朋友。</p>
        <p>秋学期 → 圣诞 → 春学期 → 复活节 → 期末考 → 论文。</p>
        <p>每天 3 个行动。这一年怎么过，由你决定。</p>
        <p className="opacity-60 italic">这次，你来掌控故事。</p>
      </div>
      <div className="max-w-sm mx-auto mt-10 grid grid-cols-2 gap-2 text-xs opacity-60" style={{ fontFamily: 'monospace' }}>
        <div className="border border-amber-300/40 p-2" style={{ color: '#d4b070' }}>🇨🇳 父母来伦敦</div>
        <div className="border border-current/30 p-2">📔 心理日记</div>
        <div className="border border-current/30 p-2">⚠️ 4:38 AM 危机</div>
        <div className="border border-current/30 p-2">📮 结局回响</div>
      </div>
      <button onClick={onStart} className="mt-10 px-12 py-3 border border-current hover:bg-current hover:text-black transition-colors duration-500 tracking-[0.3em] text-sm">
        BEGIN
      </button>
      <div className="mt-4 text-xs opacity-40 italic">建议开启声音 🔊</div>
    </div>
  );
}

function PlayingScreen(props) {
  const { day, week, dayOfWeek, stats, actionsLeft, weekInfo, tab, setTab,
    currentLocation, setCurrentLocation, onGoToLocation,
    onAttendClass, onWorkShift, onRestAtFlat, onCallHome, onTalkNPC,
    onWriteDissertation, dissertationProgress, dissertationTopic,
    onEndDay, messages, unreadMessages, onReadMessages, npcRel,
    attendanceRate, currentMonthRate, classesAttendedThisWeek, storyProgress,
    travelMode, onStartTravel, monthAttendance, examResults,
    weather, groupChat, unreadGroup, onReadGroup, addedStrangers,
    seenDreams, seenInsomnia, seenNostalgia,
    parentsChapter, flags,
    onTriggerPret, onTriggerEssay, onTriggerMatch } = props;

  const dayNames = ['一', '二', '三', '四', '五', '六', '日'];
  const attendanceColor = attendanceRate >= 80 ? '#a0c890' : attendanceRate >= 70 ? '#d4b070' : attendanceRate >= 50 ? '#d49060' : '#c86060';
  const diaryTotal = (seenDreams?.length || 0) + (seenInsomnia?.length || 0) + (seenNostalgia?.length || 0);

  // 周类型颜色和提示
  const weekColor = {
    welcome: '#d4b070', term: '#a0c890', reading: '#a0a0c8',
    vacation_xmas: '#c89090', vacation_easter: '#c890a8',
    revision: '#d4a574', exam: '#c86060', dissertation: '#9080b8',
  }[weekInfo?.type || 'term'];

  const weekTypeIcon = {
    welcome: '👋', term: '📚', reading: '📖',
    vacation_xmas: '🎄', vacation_easter: '🐣',
    revision: '☕', exam: '✍️', dissertation: '📝',
  }[weekInfo?.type || 'term'];

  return (
    <div className="animate-fadein">
      {/* 顶部状态栏 */}
      <div className="mb-3 pb-3 border-b border-current/30">
        <div className="flex justify-between items-baseline mb-2">
          <div>
            <div className="text-xs tracking-[0.2em] opacity-60" style={{ fontFamily: 'monospace' }}>DAY {String(day).padStart(3, '0')} · WEEK {week}/52</div>
            <div className="text-lg mt-0.5">
              第{week}周 · 周{dayNames[dayOfWeek-1]}
              {weather && <span className="ml-2 opacity-70 text-sm">{WEATHERS[weather]?.emoji} {WEATHERS[weather]?.cn}</span>}
            </div>
          </div>
          <div className="text-right">
            <div className="text-xs opacity-60" style={{ fontFamily: 'monospace' }}>ACTIONS</div>
            <div className="flex gap-1 mt-1 justify-end">
              {[...Array(3)].map((_, i) => (
                <div key={i} className={`w-3 h-3 rounded-full border ${i < actionsLeft ? 'bg-current/80 border-current' : 'border-current/30'}`} />
              ))}
            </div>
          </div>
        </div>
        <div className="grid grid-cols-4 gap-2 text-xs">
          <MiniStat label="学业" value={stats.academic} unit="%" />
          <MiniStat label="钱包" value={'£' + stats.wallet} />
          <MiniStat label="精力" value={stats.energy} unit="%" />
          <MiniStat label="归属" value={'???'} />
        </div>
      </div>

      {/* 学年阶段标签 */}
      {weekInfo && (
        <div className="mb-3 px-3 py-2 border flex items-center justify-between"
             style={{ borderColor: weekColor + '60', background: weekColor + '08' }}>
          <div className="flex items-center gap-2">
            <span className="text-lg">{weekTypeIcon}</span>
            <div>
              <div className="text-sm" style={{ color: weekColor }}>{weekInfo.cn}</div>
              <div className="text-xs opacity-60 italic" style={{ fontFamily: 'monospace' }}>{weekInfo.label}</div>
            </div>
          </div>
          {weekInfo.requireClass && (
            <div className="text-xs opacity-70" style={{ fontFamily: 'monospace' }}>
              {classesAttendedThisWeek}/4 课
            </div>
          )}
          {weekInfo.deadline && (
            <div className="text-xs px-2 py-0.5 border border-orange-400/60 text-orange-300 animate-pulse" style={{ fontFamily: 'monospace' }}>
              ⏰ DEADLINE
            </div>
          )}
        </div>
      )}

      {/* 出勤提示 */}
      {week > 1 && tab === 'map' && weekInfo?.requireClass && (
        <div className="mb-3 px-3 py-1.5 border border-current/20 text-xs flex justify-between items-center flex-wrap gap-2">
          <span style={{ fontFamily: 'monospace' }}>累计 <span style={{ color: attendanceColor }}>{attendanceRate}%</span></span>
          {currentMonthRate !== null && (
            <span style={{ fontFamily: 'monospace' }}>上月 {currentMonthRate}%</span>
          )}
          <span style={{ fontFamily: 'monospace' }}>本周 {classesAttendedThisWeek}/4</span>
        </div>
      )}

      {/* 论文进度（论文季显示） */}
      {weekInfo?.type === 'dissertation' && dissertationTopic && (
        <div className="mb-3 px-3 py-2 border border-purple-300/40 bg-purple-300/5">
          <div className="flex justify-between items-baseline text-xs mb-1.5">
            <span style={{ fontFamily: 'monospace' }}>📝 论文进度</span>
            <span style={{ fontFamily: 'monospace' }}>{dissertationProgress}%</span>
          </div>
          <div className="h-1 bg-current/10 relative overflow-hidden">
            <div className="absolute inset-y-0 left-0 bg-purple-300/70 transition-all duration-700"
                 style={{ width: `${dissertationProgress}%` }} />
          </div>
          <div className="text-xs opacity-60 italic mt-1.5">
            题目：{dissertationTopic.label}
          </div>
        </div>
      )}

      {/* Tab 切换 */}
      <div className="grid grid-cols-5 gap-1 mb-4 text-xs">
        <TabBtn active={tab === 'map'} onClick={() => setTab('map')}>🗺️ 地图</TabBtn>
        <TabBtn active={tab === 'phone'} onClick={() => { setTab('phone'); onReadMessages(); }}>
          💬 微信{unreadMessages > 0 && <span className="ml-1 text-orange-300">·{unreadMessages}</span>}
        </TabBtn>
        <TabBtn active={tab === 'group'} onClick={() => { setTab('group'); onReadGroup && onReadGroup(); }}>
          👥 群聊{unreadGroup > 0 && <span className="ml-1 text-orange-300">·{unreadGroup}</span>}
        </TabBtn>
        <TabBtn active={tab === 'diary'} onClick={() => setTab('diary')}>📔 日记{diaryTotal > 0 && <span className="ml-1 opacity-50">·{diaryTotal}</span>}</TabBtn>
        <TabBtn active={tab === 'story'} onClick={() => setTab('story')}>📖 故事</TabBtn>
      </div>

      {tab === 'map' && (
        <MapView locations={LOCATIONS} actionsLeft={actionsLeft} onGoToLocation={onGoToLocation}
          currentLocation={currentLocation} setCurrentLocation={setCurrentLocation}
          onAttendClass={onAttendClass} onWorkShift={onWorkShift} onRestAtFlat={onRestAtFlat}
          onCallHome={onCallHome} onTalkNPC={onTalkNPC}
          onWriteDissertation={onWriteDissertation}
          weekInfo={weekInfo}
          dissertationTopic={dissertationTopic}
          npcRel={npcRel} day={day} stats={stats} onStartTravel={onStartTravel}
          onTriggerPret={onTriggerPret}
          onTriggerEssay={onTriggerEssay}
          onTriggerMatch={onTriggerMatch}
        />
      )}
      {tab === 'phone' && <PhoneView messages={messages} npcRel={npcRel} />}
      {tab === 'group' && <GroupChatView groupChat={groupChat} addedStrangers={addedStrangers} />}
      {tab === 'diary' && <DiaryView seenDreams={seenDreams} seenInsomnia={seenInsomnia} seenNostalgia={seenNostalgia} />}
      {tab === 'story' && <StoryView storyProgress={storyProgress} npcRel={npcRel}
        monthAttendance={monthAttendance} examResults={examResults}
        parentsChapter={parentsChapter} flags={flags} />}

      <button onClick={onEndDay}
        className="w-full mt-4 py-3 border border-current/60 tracking-[0.3em] text-sm hover:bg-current hover:text-black transition-colors duration-500">
        🌙 结束今天
      </button>
    </div>
  );
}

function TabBtn({ active, onClick, children }) {
  return (
    <button onClick={onClick}
      className={`py-2 border transition-all ${active ? 'border-current bg-current/10' : 'border-current/30 opacity-60 hover:opacity-100'}`}>
      {children}
    </button>
  );
}

function MiniStat({ label, value, unit }) {
  return (
    <div className="border border-current/20 p-2 text-center">
      <div className="opacity-60 text-xs" style={{ fontFamily: 'monospace' }}>{label}</div>
      <div className="text-sm mt-0.5" style={{ fontFamily: 'monospace' }}>{value}{unit}</div>
    </div>
  );
}

function MapView({ locations, actionsLeft, onGoToLocation, currentLocation, setCurrentLocation,
  onAttendClass, onWorkShift, onRestAtFlat, onCallHome, onTalkNPC, npcRel, day, stats, onStartTravel,
  onWriteDissertation, weekInfo, dissertationTopic,
  onTriggerPret, onTriggerEssay, onTriggerMatch }) {

  if (currentLocation) {
    return <LocationView location={currentLocation} onLeave={() => setCurrentLocation(null)}
      onAttendClass={onAttendClass} onWorkShift={onWorkShift} onRestAtFlat={onRestAtFlat}
      onCallHome={onCallHome} onTalkNPC={onTalkNPC} npcRel={npcRel} day={day} stats={stats}
      onStartTravel={onStartTravel} actionsLeft={actionsLeft}
      onWriteDissertation={onWriteDissertation}
      weekInfo={weekInfo}
      dissertationTopic={dissertationTopic}
      onTriggerPret={onTriggerPret}
      onTriggerEssay={onTriggerEssay}
      onTriggerMatch={onTriggerMatch} />;
  }

  return (
    <div className="animate-fadein">
      <div className="text-xs opacity-60 mb-3 italic">今天去哪？（每个地点消耗 1 行动 + 5 精力）</div>
      <div className="grid grid-cols-2 md:grid-cols-3 gap-2">
        {locations.map(loc => (
          <button key={loc.id} onClick={() => onGoToLocation(loc)} disabled={actionsLeft <= 0}
            className="p-3 border border-current/40 hover:border-current hover:bg-current/5 transition-all text-left disabled:opacity-30 disabled:cursor-not-allowed">
            <div className="text-2xl mb-1">{loc.emoji}</div>
            <div className="text-sm font-medium">{loc.name}</div>
            <div className="text-xs opacity-50 italic mt-0.5">{loc.en}</div>
          </button>
        ))}
      </div>
    </div>
  );
}

function LocationView({ location, onLeave, onAttendClass, onWorkShift, onRestAtFlat,
  onCallHome, onTalkNPC, npcRel, day, stats, onStartTravel, actionsLeft,
  onWriteDissertation, weekInfo, dissertationTopic,
  onTriggerPret, onTriggerEssay, onTriggerMatch }) {

  const npcsHere = Object.values(NPCS).filter(n => n.locations.includes(location.id));

  // 本地点的可用行动
  const actions = [];
  if (location.id === 'flat') {
    actions.push({ label: '🛌 休息', desc: '+25精力 -1归属', onClick: onRestAtFlat });
    actions.push({ label: '📞 给家里打电话', desc: '+10归属 -3精力', onClick: onCallHome });
    if (weekInfo?.type === 'dissertation' && dissertationTopic) {
      actions.push({ label: '📝 写论文（在家）', desc: `+论文进度 -12精力`, onClick: onWriteDissertation });
      actions.push({ label: '✍️ 写一段（迷你游戏）', desc: '挑战自己 +大量论文进度', onClick: onTriggerEssay });
    }
  } else if (location.id === 'uni') {
    if (weekInfo?.requireClass) {
      actions.push({ label: '📚 上课', desc: '+6学业 -8精力 +1出勤', onClick: onAttendClass });
    } else if (weekInfo?.type === 'reading') {
      actions.push({ label: '📖 自习（无课）', desc: '+4学业 -6精力', onClick: onAttendClass });
      actions.push({ label: '🎴 复习理论卡牌', desc: '迷你游戏 +学业', onClick: onTriggerMatch });
    } else if (weekInfo?.type === 'revision') {
      actions.push({ label: '☕ 复习（备考）', desc: '+5学业 -8精力', onClick: onAttendClass });
      actions.push({ label: '🎴 复习理论卡牌', desc: '迷你游戏 +学业', onClick: onTriggerMatch });
    } else if (weekInfo?.type === 'dissertation' && dissertationTopic) {
      actions.push({ label: '📝 论文 supervision meeting', desc: `+论文进度 -10精力`, onClick: onWriteDissertation });
    }
  } else if (location.id === 'library') {
    if (weekInfo?.type === 'dissertation' && dissertationTopic) {
      actions.push({ label: '📝 写论文（图书馆）', desc: `+论文进度(更高) -10精力`, onClick: onWriteDissertation });
      actions.push({ label: '✍️ 写一段（迷你游戏）', desc: '挑战自己 +大量论文进度', onClick: onTriggerEssay });
    }
    if (['reading', 'revision'].includes(weekInfo?.type)) {
      actions.push({ label: '🎴 复习理论卡牌', desc: '迷你游戏 +学业', onClick: onTriggerMatch });
    }
  } else if (location.id === 'mei') {
    if (day > 14) actions.push({ label: '💼 打工一晚', desc: '+£50 -12精力', onClick: onWorkShift });
  } else if (location.id === 'pub') {
    actions.push({ label: '💼 打工一晚', desc: '+£50 -12精力', onClick: onWorkShift });
  } else if (location.id === 'camden' || location.id === 'tate') {
    actions.push({ label: '☕ 去 Pret 点单（迷你游戏）', desc: '练你的英语听力', onClick: onTriggerPret });
  } else if (location.id === 'station') {
    TRAVEL_DESTINATIONS.forEach(d => {
      const cond = !d.condition || d.condition({ week: weekInfo?.week, day });
      if (cond) {
        actions.push({
          label: `🚆 去${d.name} (£${d.cost})`,
          desc: `${d.days}天，${d.desc}`,
          onClick: () => onStartTravel(d),
          disabled: stats.wallet < d.cost,
        });
      }
    });
  }

  return (
    <div className="animate-fadein">
      <button onClick={onLeave} className="text-xs opacity-60 hover:opacity-100 mb-3">← 返回地图</button>
      <div className="border border-current/30 p-4 mb-3">
        <div className="text-3xl mb-2">{location.emoji}</div>
        <div className="text-xl mb-1">{location.name}</div>
        <div className="text-xs opacity-60 italic mb-2">{location.en}</div>
        <div className="text-sm opacity-80">{location.desc}</div>
      </div>

      {npcsHere.length > 0 && (
        <div className="mb-3">
          <div className="text-xs tracking-[0.2em] opacity-60 mb-2" style={{ fontFamily: 'monospace' }}>这里有人</div>
          <div className="space-y-2">
            {npcsHere.map(npc => {
              const rel = npcRel[npc.id] || 0;
              return (
                <button key={npc.id} onClick={() => onTalkNPC(npc)}
                  className="w-full flex items-center gap-3 p-3 border border-current/30 hover:border-current/70 hover:bg-current/5 transition-all text-left">
                  <div className="w-10 h-10 rounded-full flex items-center justify-center flex-shrink-0 font-medium"
                    style={{ background: npc.color, color: '#1a1612' }}>{npc.avatar}</div>
                  <div className="flex-1">
                    <div className="text-sm">{npc.cn}</div>
                    <div className="text-xs opacity-60 italic">{npc.role}</div>
                  </div>
                  <div className="text-xs opacity-60" style={{ fontFamily: 'monospace' }}>
                    {rel > 8 ? '亲近' : rel > 5 ? '熟悉' : rel > 2 ? '认识' : '陌生'}
                  </div>
                </button>
              );
            })}
          </div>
        </div>
      )}

      {actions.length > 0 && (
        <div className="mb-3">
          <div className="text-xs tracking-[0.2em] opacity-60 mb-2" style={{ fontFamily: 'monospace' }}>可以做</div>
          <div className="space-y-2">
            {actions.map((act, i) => (
              <button key={i} onClick={act.onClick} disabled={act.disabled || actionsLeft < 1}
                className="w-full p-3 border border-current/40 hover:border-current hover:bg-current/5 transition-all text-left disabled:opacity-30 disabled:cursor-not-allowed">
                <div className="text-sm">{act.label}</div>
                <div className="text-xs opacity-60 italic">{act.desc}</div>
              </button>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

function PhoneView({ messages, npcRel }) {
  if (messages.length === 0) {
    return <div className="text-center opacity-50 italic py-12 text-sm">还没有消息</div>;
  }
  return (
    <div className="animate-fadein space-y-2">
      <div className="text-xs tracking-[0.2em] opacity-60 mb-2" style={{ fontFamily: 'monospace' }}>消息</div>
      {messages.slice().reverse().map(m => (
        <div key={m.id} className="p-3 border border-current/30 animate-slidein">
          <div className="flex justify-between text-xs opacity-60 mb-1">
            <span style={{ fontFamily: 'monospace' }}>{m.fromName}</span>
            <span style={{ fontFamily: 'monospace' }}>D{m.day} · {m.time}</span>
          </div>
          <div className="text-sm">{m.text}</div>
        </div>
      ))}
    </div>
  );
}

function StoryView({ storyProgress, npcRel, monthAttendance, examResults, parentsChapter, flags }) {
  const showParentsLine = parentsChapter > 0 || flags?.parents_coming || flags?.parents_declined;
  return (
    <div className="animate-fadein space-y-3">
      {/* 父母线进度 */}
      {showParentsLine && (
        <div className="p-3 border border-amber-300/40 bg-amber-300/5">
          <div className="text-xs tracking-[0.2em] mb-2 flex justify-between" style={{ fontFamily: 'monospace', color: '#d4b070' }}>
            <span>🇨🇳 父母线</span>
            <span className="opacity-60">{parentsChapter} / 5</span>
          </div>
          {flags?.parents_declined ? (
            <div className="text-xs opacity-70 italic">你拒绝了他们这次来。后面再没机会。</div>
          ) : (
            <>
              <div className="flex gap-1 mb-2">
                {[1,2,3,4,5].map(i => (
                  <div key={i} className={`flex-1 h-0.5 ${i <= parentsChapter ? 'bg-amber-300/70' : 'bg-current/20'}`} />
                ))}
              </div>
              <div className="text-xs opacity-70 italic">
                {parentsChapter === 0 ? '妈妈还没问起来过。' :
                 parentsChapter === 1 ? '妈妈问了。等春节。' :
                 parentsChapter === 2 ? '妈妈在练 "How are you"。' :
                 parentsChapter === 3 ? '他们在伦敦。' :
                 parentsChapter === 4 ? '他们在你的伦敦。' :
                 '他们走了。'}
              </div>
            </>
          )}
        </div>
      )}
      {/* 学年进度 */}
      {(monthAttendance?.length > 0 || Object.keys(examResults || {}).length > 0) && (
        <div className="p-3 border border-current/30">
          <div className="text-xs tracking-[0.2em] opacity-60 mb-2" style={{ fontFamily: 'monospace' }}>学年进度</div>
          {monthAttendance?.length > 0 && (
            <div className="mb-3">
              <div className="text-xs opacity-70 mb-1.5">月度出勤</div>
              <div className="flex gap-1">
                {monthAttendance.map((m, i) => {
                  const c = m.rate >= 80 ? '#a0c890' : m.rate >= 70 ? '#d4b070' : m.rate >= 60 ? '#d49060' : '#c86060';
                  return (
                    <div key={i} className="flex-1 text-center">
                      <div className="text-xs" style={{ color: c, fontFamily: 'monospace' }}>{m.rate}%</div>
                      <div className="h-1 mt-1" style={{ background: c }} />
                      <div className="text-xs opacity-50 mt-0.5" style={{ fontFamily: 'monospace' }}>M{m.month}</div>
                    </div>
                  );
                })}
              </div>
            </div>
          )}
          {Object.keys(examResults || {}).length > 0 && (
            <div>
              <div className="text-xs opacity-70 mb-1.5">考试成绩</div>
              <div className="space-y-1 text-xs">
                {Object.entries(examResults).map(([id, score]) => {
                  const exam = EXAM_PAPERS.find(e => e.id === id);
                  const c = score >= 70 ? '#a0c890' : score >= 50 ? '#d4b070' : '#c86060';
                  return (
                    <div key={id} className="flex justify-between" style={{ fontFamily: 'monospace' }}>
                      <span>{exam?.cn || id}</span>
                      <span style={{ color: c }}>{score}%</span>
                    </div>
                  );
                })}
              </div>
            </div>
          )}
        </div>
      )}

      <div className="text-xs tracking-[0.2em] opacity-60 mb-2" style={{ fontFamily: 'monospace' }}>故事进度</div>
      {Object.values(STORYLINES).map(line => {
        const npc = NPCS[line.npc];
        const progress = storyProgress[line.id] || 0;
        const total = line.chapters.length;
        const rel = npcRel[line.npc] || 0;
        const nextChapter = progress < total ? line.chapters[progress] : null;
        return (
          <div key={line.id} className="p-3 border border-current/30">
            <div className="flex items-center gap-3 mb-2">
              <div className="w-8 h-8 rounded-full flex items-center justify-center text-sm font-medium"
                style={{ background: npc.color, color: '#1a1612' }}>{npc.avatar}</div>
              <div className="flex-1">
                <div className="text-sm">{line.name}</div>
                <div className="text-xs opacity-60" style={{ fontFamily: 'monospace' }}>{progress}/{total} 章</div>
              </div>
            </div>
            <div className="flex gap-1">
              {line.chapters.map((c, i) => (
                <div key={i} className={`flex-1 h-1 ${i < progress ? 'bg-current' : 'bg-current/20'}`} />
              ))}
            </div>
            {nextChapter && (
              <div className="mt-2 text-xs opacity-60 italic">
                下一章：{nextChapter.title}
                {nextChapter.trigger.rel !== undefined && rel < nextChapter.trigger.rel && (
                  <span className="opacity-80"> · 关系还差 {nextChapter.trigger.rel - rel}</span>
                )}
                {nextChapter.trigger.location && (
                  <span className="opacity-80"> · 在 {LOCATIONS.find(l => l.id === nextChapter.trigger.location)?.name}</span>
                )}
              </div>
            )}
          </div>
        );
      })}
    </div>
  );
}

// ========== 弹窗 ==========

function EventModal({ event, feedback, onChoose, onDismiss }) {
  return (
    <div className="fixed inset-0 z-40 flex items-center justify-center p-4" style={{ background: 'rgba(10, 8, 6, 0.85)' }}>
      <div className="bg-[#1a1612] border border-current/40 max-w-md w-full max-h-[90vh] overflow-y-auto p-5 animate-fadein">
        <div className="text-xs tracking-[0.3em] opacity-50 mb-2" style={{ fontFamily: 'monospace' }}>EVENT</div>
        <h2 className="text-xl mb-3 font-light">{event.title}</h2>
        <div className="text-sm leading-relaxed mb-5 opacity-90" style={{ lineHeight: '1.8' }}>{event.body}</div>
        {!feedback ? (
          (event.choices || [{ label: '继续', effect: event.effect || {}, feedback: event.feedback || '...' }]).map((c, i) => (
            <button key={i} onClick={() => onChoose(c)}
              className="w-full text-left p-3 mb-2 border border-current/40 hover:border-current hover:bg-current/5 transition-all">
              <span className="opacity-50 mr-2" style={{ fontFamily: 'monospace' }}>{String.fromCharCode(65+i)}.</span>
              {c.label}
            </button>
          ))
        ) : (
          <>
            <div className="border-l-2 border-current/50 pl-4 py-1 mb-4 italic opacity-90 text-sm" style={{ lineHeight: '1.8' }}>{feedback}</div>
            <button onClick={onDismiss} className="w-full px-6 py-2 border border-current text-sm tracking-[0.2em] hover:bg-current hover:text-black transition-colors">CONTINUE</button>
          </>
        )}
      </div>
    </div>
  );
}

function StoryModal({ chapter, lineName, feedback, onChoose, onDismiss }) {
  return (
    <div className="fixed inset-0 z-40 flex items-center justify-center p-4" style={{ background: 'rgba(10, 8, 6, 0.9)' }}>
      <div className="bg-[#1a1612] border border-amber-300/40 max-w-md w-full max-h-[90vh] overflow-y-auto p-5 animate-fadein">
        <div className="text-xs tracking-[0.3em] mb-1" style={{ fontFamily: 'monospace', color: '#d4b070' }}>📖 STORY · {lineName}</div>
        <div className="text-xs opacity-50 mb-3" style={{ fontFamily: 'monospace' }}>CHAPTER · {chapter.title}</div>
        <h2 className="text-xl mb-3 font-light">{chapter.title_full}</h2>
        <div className="text-sm leading-relaxed mb-5 opacity-90" style={{ lineHeight: '1.8' }}>{chapter.body}</div>
        {!feedback ? (
          chapter.choices.map((c, i) => (
            <button key={i} onClick={() => onChoose(c)}
              className="w-full text-left p-3 mb-2 border border-current/40 hover:border-current hover:bg-current/5 transition-all">
              <span className="opacity-50 mr-2" style={{ fontFamily: 'monospace' }}>{String.fromCharCode(65+i)}.</span>
              {c.label}
            </button>
          ))
        ) : (
          <>
            <div className="border-l-2 border-amber-300/60 pl-4 py-1 mb-4 italic opacity-90 text-sm" style={{ lineHeight: '1.8' }}>{feedback}</div>
            <button onClick={onDismiss} className="w-full px-6 py-2 border border-current text-sm tracking-[0.2em] hover:bg-current hover:text-black transition-colors">CONTINUE</button>
          </>
        )}
      </div>
    </div>
  );
}

function NpcDialogModal({ npc, rel, feedback, onChoose, onDismiss }) {
  // 动态生成对话选项
  const topics = [
    { label: '寒暄一下', effect: { rel: 1, energy: -1 },
      feedback: `你和${npc.cn}聊了天气、聊了课。一切如常。` },
    { label: '问问最近怎么样', effect: { rel: 2, energy: -2, belonging: 2 },
      feedback: `${npc.cn}讲了一些最近的事。你认真听了。这种小小的连接，正是你来这里需要的。` },
  ];

  if (rel >= 3) {
    topics.push({ label: '约 ta 一起做点什么', effect: { rel: 3, energy: -3, belonging: 4 },
      feedback: `${npc.cn}爽快地答应了。"Sure, let me know when!" 你心里一暖。` });
  }
  if (rel >= 6) {
    topics.push({ label: '聊一些深一点的话题', effect: { rel: 4, energy: -5, belonging: 8 },
      feedback: `你们聊了很久。${npc.cn}讲了一些以前没讲过的事。你也讲了。这就是友情吧。` });
  }

  return (
    <div className="fixed inset-0 z-40 flex items-center justify-center p-4" style={{ background: 'rgba(10, 8, 6, 0.85)' }}>
      <div className="bg-[#1a1612] border border-current/40 max-w-md w-full p-5 animate-fadein">
        <div className="flex items-center gap-3 mb-4">
          <div className="w-12 h-12 rounded-full flex items-center justify-center font-medium text-lg"
            style={{ background: npc.color, color: '#1a1612' }}>{npc.avatar}</div>
          <div>
            <div className="text-lg">{npc.cn}</div>
            <div className="text-xs opacity-60 italic">{npc.role} · 关系 {rel}</div>
          </div>
        </div>
        <div className="text-sm opacity-80 italic mb-4" style={{ lineHeight: '1.7' }}>{npc.bio}</div>
        {!feedback ? (
          <>
            <div className="text-xs opacity-60 mb-2" style={{ fontFamily: 'monospace' }}>选个话题</div>
            {topics.map((t, i) => (
              <button key={i} onClick={() => onChoose(t)}
                className="w-full text-left p-2.5 mb-2 border border-current/40 hover:border-current hover:bg-current/5 transition-all text-sm">
                {t.label}
              </button>
            ))}
            <button onClick={onDismiss} className="w-full mt-2 p-2 text-xs opacity-60 hover:opacity-100">
              先这样吧 →
            </button>
          </>
        ) : (
          <>
            <div className="border-l-2 border-current/50 pl-4 py-1 mb-4 italic opacity-90 text-sm" style={{ lineHeight: '1.8' }}>{feedback}</div>
            <button onClick={onDismiss} className="w-full px-6 py-2 border border-current text-sm tracking-[0.2em] hover:bg-current hover:text-black transition-colors">CONTINUE</button>
          </>
        )}
      </div>
    </div>
  );
}

// ========== 迷你游戏：抢黄标 ==========

function YellowLabelMinigame({ onComplete, feedback, onDismiss }) {
  const [phase, setPhase] = useState('ready'); // ready | playing | done
  const [items, setItems] = useState([]);
  const [grabbed, setGrabbed] = useState([]);
  const [timeLeft, setTimeLeft] = useState(5);
  const timerRef = useRef(null);

  function start() {
    audio.click();
    // 随机洗牌商品
    const shuffled = [...YELLOW_LABEL_ITEMS].sort(() => Math.random() - 0.5);
    setItems(shuffled);
    setGrabbed([]);
    setTimeLeft(5);
    setPhase('playing');
    timerRef.current = setInterval(() => {
      setTimeLeft(t => {
        if (t <= 1) {
          clearInterval(timerRef.current);
          setPhase('done');
          return 0;
        }
        return t - 1;
      });
    }, 1000);
  }

  function grab(item, idx) {
    if (phase !== 'playing') return;
    if (grabbed.includes(idx)) return;
    audio.click();
    setGrabbed([...grabbed, idx]);
  }

  function finish() {
    if (phase !== 'done') {
      clearInterval(timerRef.current);
      setPhase('done');
    }
    const yellow = grabbed.filter(idx => items[idx]?.isYellow);
    const wrong = grabbed.filter(idx => !items[idx]?.isYellow);
    const totalSavings = yellow.reduce((s, idx) => s + items[idx].price, 0);
    const totalCost = grabbed.reduce((s, idx) => s + items[idx].price, 0);
    const result = {
      success: yellow.length >= 2 && wrong.length === 0,
      cost: totalCost,
      energy: yellow.length * 2 - wrong.length,
      belonging: yellow.length >= 2 ? 3 : 0,
      feedback: yellow.length >= 2 && wrong.length === 0
        ? `你抢到了 ${yellow.length} 件黄标商品！总共花了 £${totalCost}。其他亚洲面孔向你点了点头，某种隐秘的同盟。`
        : wrong.length > 0
        ? `你抢到了一些东西，但有 ${wrong.length} 件不是黄标。你看了看小票：£${totalCost}。算了，回家煮泡面。`
        : `你什么都没抢到。回家路上下起了雨。`,
    };
    onComplete(result);
  }

  useEffect(() => () => clearInterval(timerRef.current), []);

  return (
    <div className="fixed inset-0 z-40 flex items-center justify-center p-4" style={{ background: 'rgba(10, 8, 6, 0.9)' }}>
      <div className="bg-[#1a1612] border border-current/40 max-w-md w-full p-5 animate-fadein">
        <div className="text-xs tracking-[0.3em] opacity-50 mb-2" style={{ fontFamily: 'monospace' }}>MINIGAME</div>
        <h2 className="text-xl mb-3 font-light">🛒 抢黄标</h2>

        {phase === 'ready' && (
          <>
            <div className="text-sm opacity-90 mb-4" style={{ lineHeight: '1.8' }}>
              晚上 9 点。Tesco 员工推着小车出来。<br/>
              5 秒内点击带 <span style={{ color: '#d4b070' }}>黄标</span> 的商品（贴纸为黄色的）。<br/>
              <span className="opacity-60 italic text-xs">⚠️ 别抢错了，原价的会扣钱。</span>
            </div>
            <button onClick={start} className="w-full py-3 border border-current hover:bg-current hover:text-black transition-colors tracking-[0.2em] text-sm">
              开始
            </button>
            <button onClick={onDismiss} className="w-full mt-2 p-2 text-xs opacity-60 hover:opacity-100">放弃 →</button>
          </>
        )}

        {phase === 'playing' && (
          <>
            <div className="flex justify-between mb-3 items-center">
              <div className="text-sm opacity-80">已抢 {grabbed.length}</div>
              <div className="text-2xl" style={{ fontFamily: 'monospace', color: timeLeft <= 2 ? '#c86060' : '#e8e0d0' }}>{timeLeft}</div>
            </div>
            <div className="grid grid-cols-3 gap-2">
              {items.map((item, idx) => {
                const taken = grabbed.includes(idx);
                return (
                  <button key={idx} onClick={() => grab(item, idx)} disabled={taken}
                    className={`relative aspect-square border ${taken ? 'border-current/20 opacity-30' : 'border-current/40 hover:border-current hover:bg-current/5'} transition-all flex flex-col items-center justify-center`}>
                    {item.isYellow && !taken && (
                      <div className="absolute top-1 right-1 px-1 text-[8px]" style={{ background: '#d4b070', color: '#1a1612', fontFamily: 'monospace' }}>£{item.price}</div>
                    )}
                    <div className="text-3xl">{item.emoji}</div>
                    <div className="text-xs mt-1 opacity-70">{item.name}</div>
                  </button>
                );
              })}
            </div>
            <button onClick={finish} className="w-full mt-3 py-2 border border-current/40 text-xs tracking-[0.2em] hover:bg-current/10 transition-all">
              停手 →
            </button>
          </>
        )}

        {phase === 'done' && !feedback && (
          <>
            <div className="text-sm opacity-90 mb-4" style={{ lineHeight: '1.8' }}>
              时间到。你抢到了 {grabbed.length} 件商品。
            </div>
            <button onClick={finish} className="w-full py-3 border border-current hover:bg-current hover:text-black transition-colors tracking-[0.2em] text-sm">
              查看结果
            </button>
          </>
        )}

        {feedback && (
          <>
            <div className="border-l-2 border-current/50 pl-4 py-1 mb-4 italic opacity-90 text-sm" style={{ lineHeight: '1.8' }}>{feedback}</div>
            <button onClick={onDismiss} className="w-full px-6 py-2 border border-current text-sm tracking-[0.2em] hover:bg-current hover:text-black transition-colors">CONTINUE</button>
          </>
        )}
      </div>
    </div>
  );
}

function HolidayScreen({ type, choices, secrets, stats, npcRel, storyProgress, flags, feedback, onChoose, onDismiss }) {
  const config = type === 'xmas'
    ? { title: '🎄 圣诞假期', subtitle: 'Christmas Vacation · 3 weeks',
        intro: '12月23日。学校关门四周。\n\n大部分英国学生回家了。Tesco 营业时间缩短。中餐馆关三天。\n\n你怎么过这个圣诞？' }
    : { title: '🐣 复活节假期', subtitle: 'Easter Vacation · 4 weeks',
        intro: '4月初。复活节假期开始。\n\n4 周时间，没人管你。期末考还有一个月。\n\n你想怎么用这段时间？' };

  // 计算解锁的隐藏剧情
  const unlockedSecrets = (secrets || []).filter(s =>
    s.condition({ npcRel: npcRel || {}, storyProgress: storyProgress || {}, flags: flags || {} })
  );

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4" style={{ background: 'rgba(10, 8, 6, 0.95)' }}>
      <div className="bg-[#1a1612] border border-amber-300/40 max-w-md w-full max-h-[90vh] overflow-y-auto p-5 animate-fadein">
        <div className="text-xs tracking-[0.3em] opacity-50 mb-1" style={{ fontFamily: 'monospace' }}>HOLIDAY</div>
        <h2 className="text-2xl mb-1 font-light">{config.title}</h2>
        <div className="text-xs opacity-60 italic mb-4" style={{ fontFamily: 'monospace' }}>{config.subtitle}</div>

        {!feedback ? (
          <>
            <div className="text-sm opacity-90 mb-5 whitespace-pre-line" style={{ lineHeight: '1.8' }}>{config.intro}</div>

            {/* 隐藏剧情区域（如果有解锁的） */}
            {unlockedSecrets.length > 0 && (
              <div className="mb-4">
                <div className="flex items-center gap-2 mb-2">
                  <div className="flex-1 h-px bg-amber-300/30" />
                  <div className="text-xs tracking-[0.3em]" style={{ fontFamily: 'monospace', color: '#d4b070' }}>
                    ⭐ SPECIAL
                  </div>
                  <div className="flex-1 h-px bg-amber-300/30" />
                </div>
                <div className="space-y-2">
                  {unlockedSecrets.map((s) => {
                    const cantAfford = (s.effect.wallet || 0) < 0 && stats.wallet + s.effect.wallet < 0;
                    const npc = s.npc ? NPCS[s.npc] : null;
                    return (
                      <button key={s.id} onClick={() => !cantAfford && onChoose(s)} disabled={cantAfford}
                        className={`w-full text-left p-3 border-2 transition-all relative ${cantAfford ? 'border-amber-300/20 opacity-30 cursor-not-allowed' : 'border-amber-300/50 hover:border-amber-300 hover:bg-amber-300/5'}`}
                        style={{ background: cantAfford ? undefined : 'linear-gradient(135deg, rgba(212,176,112,0.04), transparent)' }}>
                        <div className="flex items-start gap-2">
                          {npc && (
                            <div className="w-7 h-7 rounded-full flex items-center justify-center text-xs flex-shrink-0 font-medium"
                              style={{ background: npc.color, color: '#1a1612' }}>{npc.avatar}</div>
                          )}
                          <div className="flex-1">
                            <div className="text-sm font-medium flex items-center gap-2">
                              <span>{s.label}</span>
                              <span className="text-xs px-1.5 py-0.5 border border-amber-300/40 rounded" style={{ color: '#d4b070', fontFamily: 'monospace' }}>SECRET</span>
                            </div>
                            <div className="text-xs opacity-60 italic mt-0.5">{s.desc}{cantAfford && ' · 钱不够'}</div>
                          </div>
                        </div>
                      </button>
                    );
                  })}
                </div>
                <div className="flex items-center gap-2 mt-2 mb-3">
                  <div className="flex-1 h-px bg-current/20" />
                  <div className="text-xs opacity-50" style={{ fontFamily: 'monospace' }}>OR</div>
                  <div className="flex-1 h-px bg-current/20" />
                </div>
              </div>
            )}

            {/* 普通选项 */}
            <div className="space-y-2">
              {choices.map((c, i) => {
                const cantAfford = (c.effect.wallet || 0) < 0 && stats.wallet + c.effect.wallet < 0;
                return (
                  <button key={i} onClick={() => !cantAfford && onChoose(c)} disabled={cantAfford}
                    className={`w-full text-left p-3 border ${cantAfford ? 'border-current/10 opacity-30 cursor-not-allowed' : 'border-current/40 hover:border-current hover:bg-current/5'} transition-all`}>
                    <div className="text-sm font-medium">{c.label}</div>
                    <div className="text-xs opacity-60 italic mt-0.5">{c.desc}{cantAfford && ' · 钱不够'}</div>
                  </button>
                );
              })}
            </div>
          </>
        ) : (
          <>
            <div className="border-l-2 border-amber-300/60 pl-4 py-1 mb-4 italic opacity-90 text-sm" style={{ lineHeight: '1.8' }}>{feedback}</div>
            <button onClick={onDismiss} className="w-full px-6 py-2 border border-current text-sm tracking-[0.2em] hover:bg-current hover:text-black transition-colors">回到伦敦</button>
          </>
        )}
      </div>
    </div>
  );
}

function ExamScreen({ exam, academic, onFinish }) {
  const [phase, setPhase] = useState('intro');
  const [currentQ, setCurrentQ] = useState(0);
  const [answers, setAnswers] = useState([]);
  const [score, setScore] = useState(0);

  function start() { audio.click(); setPhase('quiz'); }

  function answer(choiceIdx) {
    audio.click();
    const q = exam.questions[currentQ];
    const correct = choiceIdx === q.correct;
    const newAnswers = [...answers, { q: currentQ, picked: choiceIdx, correct }];
    setAnswers(newAnswers);
    if (currentQ + 1 < exam.questions.length) {
      setCurrentQ(currentQ + 1);
    } else {
      // 计算分数 (50% from quiz + 50% from academic stat)
      const quizScore = (newAnswers.filter(a => a.correct).length / exam.questions.length) * 100;
      const finalScore = Math.round(quizScore * 0.6 + academic * 0.4);
      setScore(finalScore);
      setPhase('result');
    }
  }

  function done() { audio.click(); onFinish(score); }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4" style={{ background: 'rgba(10, 8, 6, 0.95)' }}>
      <div className="bg-[#1a1612] border border-red-400/40 max-w-md w-full max-h-[90vh] overflow-y-auto p-5 animate-fadein">
        <div className="text-xs tracking-[0.3em] mb-1" style={{ fontFamily: 'monospace', color: '#c86060' }}>✍️ FINAL EXAM</div>
        <h2 className="text-xl mb-1 font-light">{exam.subject}</h2>
        <div className="text-xs opacity-60 italic mb-4" style={{ fontFamily: 'monospace' }}>{exam.cn}</div>

        {phase === 'intro' && (
          <>
            <div className="text-sm opacity-90 mb-5" style={{ lineHeight: '1.8' }}>
              考试时间：3 小时<br/>
              形式：5 道选择题<br/>
              <span className="opacity-70 italic">最终成绩 = 60% 答题正确率 + 40% 平时学业积累。所以平时不下功夫，临场也救不了你。</span>
            </div>
            <button onClick={start} className="w-full py-3 border border-current hover:bg-current hover:text-black transition-colors tracking-[0.2em] text-sm">
              开始考试
            </button>
          </>
        )}

        {phase === 'quiz' && (
          <>
            <div className="text-xs opacity-60 mb-2" style={{ fontFamily: 'monospace' }}>问题 {currentQ + 1} / {exam.questions.length}</div>
            <div className="text-sm mb-4 leading-relaxed" style={{ lineHeight: '1.7' }}>{exam.questions[currentQ].q}</div>
            <div className="space-y-2">
              {exam.questions[currentQ].options.map((opt, i) => (
                <button key={i} onClick={() => answer(i)}
                  className="w-full text-left p-3 border border-current/40 hover:border-current hover:bg-current/5 transition-all text-sm">
                  <span className="opacity-50 mr-2" style={{ fontFamily: 'monospace' }}>{String.fromCharCode(65 + i)}.</span>
                  {opt}
                </button>
              ))}
            </div>
          </>
        )}

        {phase === 'result' && (
          <>
            <div className="text-center my-6">
              <div className="text-xs opacity-60 mb-1" style={{ fontFamily: 'monospace' }}>YOUR MARK</div>
              <div className="text-6xl font-light" style={{ color: score >= 70 ? '#a0c890' : score >= 50 ? '#d4b070' : '#c86060', fontFamily: 'monospace' }}>{score}</div>
              <div className="text-sm opacity-70 italic mt-2">
                {score >= 70 ? 'Distinction · 优秀' : score >= 60 ? 'Merit · 良好' : score >= 50 ? 'Pass · 及格' : 'Fail · 挂科'}
              </div>
            </div>
            <div className="text-sm opacity-80 italic mb-5 text-center" style={{ lineHeight: '1.7' }}>
              {score >= 70 ? '走出考场你给自己买了杯 £4.5 的拿铁。今天值得。'
                : score >= 50 ? '没有大获全胜，但也没翻车。这就够了。'
                : '你坐在长椅上发了 20 分钟呆。然后你回家煮了一碗面。明天还要继续。'}
            </div>
            <button onClick={done} className="w-full px-6 py-2 border border-current text-sm tracking-[0.2em] hover:bg-current hover:text-black transition-colors">CONTINUE</button>
          </>
        )}
      </div>
    </div>
  );
}

function DissertationTopicScreen({ feedback, onChoose, onDismiss }) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4" style={{ background: 'rgba(10, 8, 6, 0.95)' }}>
      <div className="bg-[#1a1612] border border-purple-300/40 max-w-md w-full max-h-[90vh] overflow-y-auto p-5 animate-fadein">
        <div className="text-xs tracking-[0.3em] mb-1" style={{ fontFamily: 'monospace', color: '#9080b8' }}>📝 DISSERTATION</div>
        <h2 className="text-xl mb-1 font-light">选一个论文方向</h2>
        <div className="text-xs opacity-60 italic mb-4" style={{ fontFamily: 'monospace' }}>15,000 字 · 接下来 16 周</div>

        {!feedback ? (
          <>
            <div className="text-sm opacity-90 mb-5" style={{ lineHeight: '1.8' }}>
              这是你硕士的 50%。Whitmore 让你在三个方向里选一个。<br/>
              <span className="opacity-70 italic">你的选择不只决定分数，也决定你这一年到底想成为一个什么样的人。</span>
            </div>
            <div className="space-y-2">
              {DISSERTATION_TOPICS.map((t, i) => (
                <button key={i} onClick={() => onChoose(t)}
                  className="w-full text-left p-3 border border-current/40 hover:border-current hover:bg-current/5 transition-all">
                  <div className="text-sm font-medium">{t.label}</div>
                  <div className="text-xs opacity-60 italic mt-0.5">{t.desc}</div>
                </button>
              ))}
            </div>
          </>
        ) : (
          <>
            <div className="border-l-2 border-purple-300/60 pl-4 py-1 mb-4 italic opacity-90 text-sm" style={{ lineHeight: '1.8' }}>{feedback}</div>
            <button onClick={onDismiss} className="w-full px-6 py-2 border border-current text-sm tracking-[0.2em] hover:bg-current hover:text-black transition-colors">开始动笔</button>
          </>
        )}
      </div>
    </div>
  );
}

function StrangerEncounterModal({ stranger, onAdd, onReject }) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 animate-fadein" style={{ background: 'rgba(10, 8, 6, 0.92)' }}>
      <div className="bg-[#1a1612] border border-current/40 max-w-md w-full p-5">
        <div className="text-xs tracking-[0.3em] opacity-50 mb-1" style={{ fontFamily: 'monospace' }}>📱 偶遇</div>
        <h2 className="text-xl mb-1 font-light">{stranger.encounterTitle}</h2>
        <div className="text-sm leading-relaxed mb-5 opacity-90 whitespace-pre-line" style={{ lineHeight: '1.85' }}>
          {stranger.encounterBody}
        </div>

        <div className="flex items-center gap-3 px-3 py-2 mb-4 border border-current/20 bg-current/5">
          <div className="w-9 h-9 rounded-full flex items-center justify-center text-sm font-medium flex-shrink-0"
            style={{ background: stranger.color, color: '#1a1612' }}>{stranger.avatar}</div>
          <div className="flex-1 min-w-0">
            <div className="text-sm">{stranger.name}</div>
            <div className="text-xs opacity-60 italic" style={{ fontFamily: 'monospace' }}>{stranger.role}</div>
          </div>
        </div>

        <div className="space-y-2">
          <button onClick={() => onAdd(stranger)}
            className="w-full text-left p-3 border border-amber-300/50 hover:border-amber-300 hover:bg-amber-300/5 transition-all">
            <div className="text-sm">扫码加好友 · 拉进群</div>
            <div className="text-xs opacity-60 italic mt-0.5">+1 群成员 · +少量归属感</div>
          </button>
          <button onClick={onReject}
            className="w-full text-left p-3 border border-current/30 hover:border-current/60 transition-all">
            <div className="text-sm">"今天有点忙 改天" 客气拒绝</div>
            <div className="text-xs opacity-60 italic mt-0.5">下次可能就遇不到了</div>
          </button>
        </div>
      </div>
    </div>
  );
}

function AtYouModal({ event, members, strangers, feedback, onChoose, onDismiss }) {
  const member = (members || []).find(g => g.id === event.askerId)
              || (strangers || []).find(s => s.id === event.askerId);
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 animate-fadein" style={{ background: 'rgba(10, 8, 6, 0.92)' }}>
      <div className="bg-[#1a1612] border border-orange-300/40 max-w-md w-full max-h-[90vh] overflow-y-auto p-5">
        <div className="text-xs tracking-[0.3em] mb-1" style={{ fontFamily: 'monospace', color: '#d49060' }}>👥 群里有人 @ 你</div>
        <div className="text-xs opacity-60 italic mb-3" style={{ fontFamily: 'monospace' }}>{event.setup}</div>

        {/* 群消息气泡 */}
        {member && (
          <div className="flex gap-2 items-start mb-4 p-3 bg-current/5 rounded">
            <div className="w-8 h-8 rounded-full flex items-center justify-center text-xs font-medium flex-shrink-0"
              style={{ background: member.color, color: '#1a1612' }}>{member.avatar}</div>
            <div className="flex-1 min-w-0">
              <div className="text-xs opacity-60 mb-0.5" style={{ fontFamily: 'monospace' }}>{member.name}</div>
              <div className="text-sm" style={{ lineHeight: '1.6' }}>{event.askerMsg}</div>
            </div>
          </div>
        )}

        {!feedback ? (
          <>
            <div className="text-xs tracking-[0.2em] opacity-60 mb-2" style={{ fontFamily: 'monospace' }}>怎么回？</div>
            <div className="space-y-2">
              {event.choices.map((c, i) => (
                <button key={i} onClick={() => onChoose(c)}
                  className="w-full text-left p-3 border border-current/40 hover:border-orange-300 hover:bg-orange-300/5 transition-all">
                  <div className="text-sm">{c.label}</div>
                </button>
              ))}
            </div>
          </>
        ) : (
          <>
            <div className="border-l-2 border-orange-300/60 pl-4 py-1 mb-4 italic opacity-90 text-sm whitespace-pre-line" style={{ lineHeight: '1.85' }}>
              {feedback}
            </div>
            <button onClick={onDismiss} className="w-full px-6 py-2 border border-current text-sm tracking-[0.2em] hover:bg-current hover:text-black transition-colors">
              CONTINUE
            </button>
          </>
        )}
      </div>
    </div>
  );
}

function DreamModal({ dream, onDismiss }) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 animate-fadein"
      style={{ background: 'radial-gradient(ellipse at center, rgba(40, 30, 60, 0.94) 0%, rgba(10, 8, 20, 0.98) 100%)' }}>
      <div className="bg-[#181420] border border-purple-300/30 max-w-md w-full p-6"
        style={{ boxShadow: '0 0 80px rgba(120, 90, 180, 0.15)' }}>
        <div className="text-xs tracking-[0.4em] mb-2" style={{ fontFamily: 'monospace', color: '#a89cc0' }}>
          ☾ 凌晨 · 一场梦
        </div>
        <h2 className="text-xl mb-4 font-light italic" style={{ color: '#c8b8e0' }}>{dream.title}</h2>
        <div className="text-sm leading-relaxed mb-6 opacity-85 whitespace-pre-line italic" style={{ lineHeight: '2', color: '#d8d0e8' }}>
          {dream.body}
        </div>
        <button onClick={onDismiss}
          className="w-full px-6 py-2 border border-purple-300/40 text-sm tracking-[0.2em] hover:bg-purple-300/10 transition-colors"
          style={{ color: '#c8b8e0' }}>
          醒来
        </button>
      </div>
    </div>
  );
}

function InsomniaModal({ thought, onDismiss }) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 animate-fadein"
      style={{ background: 'rgba(8, 6, 4, 0.96)' }}>
      <div className="bg-[#15110d] border border-current/20 max-w-md w-full p-6">
        <div className="text-xs tracking-[0.4em] mb-2 opacity-60" style={{ fontFamily: 'monospace' }}>☾ 失眠</div>
        <h2 className="text-xl mb-4 font-light italic opacity-90">{thought.title}</h2>
        <div className="text-sm leading-relaxed mb-6 opacity-80 whitespace-pre-line" style={{ lineHeight: '2.1' }}>
          {thought.body}
        </div>
        <button onClick={onDismiss}
          className="w-full px-6 py-2 border border-current/40 text-sm tracking-[0.2em] hover:bg-current/10 transition-colors opacity-80">
          天亮了
        </button>
        <div className="text-xs opacity-40 italic mt-3 text-center">+5 精力 · -3 归属</div>
      </div>
    </div>
  );
}

function NostalgiaModal({ moment, onDismiss }) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 animate-fadein"
      style={{ background: 'rgba(20, 10, 6, 0.94)' }}>
      <div className="bg-[#1c1410] border border-red-300/20 max-w-md w-full p-6">
        <div className="text-xs tracking-[0.4em] mb-2" style={{ fontFamily: 'monospace', color: '#c89090' }}>
          🏮 想家
        </div>
        <h2 className="text-xl mb-4 font-light italic" style={{ color: '#e8c8c0' }}>{moment.title}</h2>
        <div className="text-sm leading-relaxed mb-6 opacity-90 whitespace-pre-line" style={{ lineHeight: '2', color: '#e0d0c8' }}>
          {moment.body}
        </div>
        <button onClick={onDismiss}
          className="w-full px-6 py-2 border border-red-300/30 text-sm tracking-[0.2em] hover:bg-red-300/5 transition-colors"
          style={{ color: '#e8c8c0' }}>
          继续
        </button>
        <div className="text-xs opacity-40 italic mt-3 text-center">-8 归属 · 但下次给妈妈打电话会更有意义</div>
      </div>
    </div>
  );
}

function ParentsChapterModal({ chapter, feedback, onChoose, onDismiss }) {
  const totalChapters = 5;
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 animate-fadein"
      style={{ background: 'radial-gradient(ellipse at top, rgba(60, 30, 20, 0.95), rgba(10, 5, 4, 0.99))' }}>
      <div className="bg-[#1c1410] border max-w-md w-full max-h-[92vh] overflow-y-auto p-6"
        style={{ borderColor: 'rgba(212, 176, 112, 0.4)', boxShadow: '0 0 80px rgba(212, 176, 112, 0.1)' }}>
        <div className="flex justify-between items-baseline mb-2">
          <div className="text-xs tracking-[0.4em]" style={{ fontFamily: 'monospace', color: '#d4b070' }}>
            🇨🇳 父母 · 第 {chapter.chapter} 章 / 共 {totalChapters} 章
          </div>
        </div>
        <h2 className="text-2xl mb-1 font-light" style={{ color: '#f0d8b0' }}>{chapter.title}</h2>
        <div className="flex gap-1 mb-5">
          {[...Array(totalChapters)].map((_, i) => (
            <div key={i} className={`flex-1 h-0.5 ${i < chapter.chapter ? 'bg-amber-300/70' : 'bg-current/20'}`} />
          ))}
        </div>

        <div className="text-sm leading-relaxed mb-6 opacity-95 whitespace-pre-line" style={{ lineHeight: '2.05', color: '#e0d4c0' }}>
          {chapter.body}
        </div>

        {!feedback ? (
          <div className="space-y-2">
            {chapter.choices.map((c, i) => (
              <button key={i} onClick={() => onChoose(c)}
                className="w-full text-left p-3 border border-amber-300/40 hover:border-amber-300 hover:bg-amber-300/5 transition-all text-sm"
                style={{ lineHeight: '1.6' }}>
                {c.label}
              </button>
            ))}
          </div>
        ) : (
          <>
            <div className="border-l-2 border-amber-300/60 pl-4 py-1 mb-4 italic opacity-95 text-sm whitespace-pre-line"
              style={{ lineHeight: '2.05', color: '#e8d4b8' }}>
              {feedback}
            </div>
            <button onClick={onDismiss}
              className="w-full px-6 py-2.5 border border-amber-300/60 text-sm tracking-[0.2em] hover:bg-amber-300/10 transition-colors"
              style={{ color: '#f0d8b0' }}>
              {chapter.chapter === 5 ? '走出 Heathrow' : 'CONTINUE'}
            </button>
          </>
        )}
      </div>
    </div>
  );
}

function StrangerEventModal({ event, strangers, feedback, onChoose, onDismiss }) {
  const stranger = strangers.find(s => s.id === event.strangerId);
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 animate-fadein" style={{ background: 'rgba(10, 8, 6, 0.92)' }}>
      <div className="bg-[#1a1612] border border-current/40 max-w-md w-full max-h-[90vh] overflow-y-auto p-5">
        <div className="text-xs tracking-[0.3em] mb-1 opacity-60" style={{ fontFamily: 'monospace' }}>📱 群里的朋友</div>
        <h2 className="text-xl mb-3 font-light">{event.title}</h2>

        {stranger && (
          <div className="flex items-center gap-2 mb-3 px-3 py-2 border border-current/20 bg-current/5">
            <div className="w-8 h-8 rounded-full flex items-center justify-center text-xs font-medium flex-shrink-0"
              style={{ background: stranger.color, color: '#1a1612' }}>{stranger.avatar}</div>
            <div className="text-xs">
              <div>{stranger.name}</div>
              <div className="opacity-60 italic" style={{ fontFamily: 'monospace' }}>{stranger.role}</div>
            </div>
          </div>
        )}

        <div className="text-sm leading-relaxed mb-5 opacity-90 whitespace-pre-line" style={{ lineHeight: '1.85' }}>
          {event.body}
        </div>

        {!feedback ? (
          <div className="space-y-2">
            {event.choices.map((c, i) => (
              <button key={i} onClick={() => onChoose(c)}
                className="w-full text-left p-3 border border-current/40 hover:border-current hover:bg-current/5 transition-all text-sm">
                <span className="opacity-50 mr-2" style={{ fontFamily: 'monospace' }}>{String.fromCharCode(65 + i)}.</span>
                {c.label}
              </button>
            ))}
          </div>
        ) : (
          <>
            <div className="border-l-2 border-current/50 pl-4 py-1 mb-4 italic opacity-90 text-sm whitespace-pre-line" style={{ lineHeight: '1.85' }}>
              {feedback}
            </div>
            <button onClick={onDismiss} className="w-full px-6 py-2 border border-current text-sm tracking-[0.2em] hover:bg-current hover:text-black transition-colors">
              CONTINUE
            </button>
          </>
        )}
      </div>
    </div>
  );
}

function CrisisModal({ crisis, feedback, onChoose, onDismiss }) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 animate-fadein"
      style={{ background: 'radial-gradient(ellipse at center, rgba(60, 20, 30, 0.96) 0%, rgba(10, 5, 8, 0.99) 100%)' }}>
      <div className="bg-[#1a0e10] border border-red-400/30 max-w-md w-full p-6"
        style={{ boxShadow: '0 0 80px rgba(180, 60, 80, 0.15)' }}>
        <div className="text-xs tracking-[0.4em] mb-2" style={{ fontFamily: 'monospace', color: '#d49090' }}>
          ⚠️ 4:38 AM
        </div>
        <h2 className="text-xl mb-4 font-light italic" style={{ color: '#e8b8b8' }}>{crisis.title}</h2>
        <div className="text-sm leading-relaxed mb-6 opacity-90 whitespace-pre-line italic" style={{ lineHeight: '2', color: '#e0c8c8' }}>
          {crisis.body}
        </div>

        {!feedback ? (
          <div className="space-y-2">
            <button onClick={() => onChoose({ id: 'quit' })}
              className="w-full text-left p-3 border border-red-400/40 hover:border-red-400 hover:bg-red-400/5 transition-all text-sm"
              style={{ color: '#e8b8b8' }}>
              <div>现在就订机票回国</div>
              <div className="text-xs opacity-60 italic mt-0.5">这是终结这一年的方式</div>
            </button>
            <button onClick={() => onChoose({ id: 'persist' })}
              className="w-full text-left p-3 border border-current/40 hover:border-current/70 transition-all text-sm">
              <div>"再坚持一周看看"</div>
              <div className="text-xs opacity-60 italic mt-0.5">放下手机，睡觉</div>
            </button>
            <button onClick={() => onChoose({ id: 'call_mom' })}
              className="w-full text-left p-3 border border-amber-300/40 hover:border-amber-300 hover:bg-amber-300/5 transition-all text-sm">
              <div>给妈妈打个电话</div>
              <div className="text-xs opacity-60 italic mt-0.5">中国是中午 12:38</div>
            </button>
          </div>
        ) : (
          <>
            <div className="border-l-2 border-red-400/40 pl-4 py-1 mb-4 italic opacity-90 text-sm whitespace-pre-line" style={{ lineHeight: '2' }}>
              {feedback}
            </div>
            <button onClick={onDismiss} className="w-full px-6 py-2 border border-current text-sm tracking-[0.2em] hover:bg-current hover:text-black transition-colors">
              天亮了
            </button>
          </>
        )}
      </div>
    </div>
  );
}

function DiaryView({ seenDreams, seenInsomnia, seenNostalgia }) {
  const [section, setSection] = useState('all');
  const dreamEntries = (seenDreams || []).map(id => DREAMS.find(d => d.id === id)).filter(Boolean).map(d => ({...d, type: 'dream'}));
  const insomniaEntries = (seenInsomnia || []).map(id => INSOMNIA_THOUGHTS.find(i => i.id === id)).filter(Boolean).map(d => ({...d, type: 'insomnia'}));
  const nostalgiaEntries = (seenNostalgia || []).map(id => NOSTALGIA_MOMENTS.find(n => n.id === id)).filter(Boolean).map(d => ({...d, type: 'nostalgia'}));

  let entries = [];
  if (section === 'all') entries = [...dreamEntries, ...insomniaEntries, ...nostalgiaEntries];
  else if (section === 'dream') entries = dreamEntries;
  else if (section === 'insomnia') entries = insomniaEntries;
  else if (section === 'nostalgia') entries = nostalgiaEntries;

  const total = dreamEntries.length + insomniaEntries.length + nostalgiaEntries.length;

  if (total === 0) {
    return (
      <div className="animate-fadein text-center py-12">
        <div className="text-sm opacity-50 italic mb-3">日记还是空的。</div>
        <div className="text-xs opacity-40 italic" style={{ lineHeight: '1.8' }}>
          这本子会自己写满。<br/>
          等你梦到、等你失眠、等你想家。
        </div>
      </div>
    );
  }

  const typeStyle = {
    dream: { color: '#c8b8e0', icon: '☾', label: '梦' },
    insomnia: { color: '#a8a09c', icon: '☾', label: '失眠' },
    nostalgia: { color: '#e8c8c0', icon: '🏮', label: '想家' },
  };

  return (
    <div className="animate-fadein">
      <div className="text-xs tracking-[0.2em] opacity-60 mb-2 flex justify-between" style={{ fontFamily: 'monospace' }}>
        <span>📔 日记</span>
        <span className="opacity-50">{total} 条</span>
      </div>

      {/* 分类切换 */}
      <div className="grid grid-cols-4 gap-1 mb-3 text-xs">
        <button onClick={() => setSection('all')}
          className={`py-1.5 border ${section === 'all' ? 'border-current bg-current/10' : 'border-current/30 opacity-60'}`}>
          全部 {total}
        </button>
        <button onClick={() => setSection('dream')}
          className={`py-1.5 border ${section === 'dream' ? 'border-purple-300/70 bg-purple-300/10' : 'border-current/30 opacity-60'}`}>
          ☾ 梦 {dreamEntries.length}
        </button>
        <button onClick={() => setSection('insomnia')}
          className={`py-1.5 border ${section === 'insomnia' ? 'border-current bg-current/10' : 'border-current/30 opacity-60'}`}>
          失眠 {insomniaEntries.length}
        </button>
        <button onClick={() => setSection('nostalgia')}
          className={`py-1.5 border ${section === 'nostalgia' ? 'border-red-300/60 bg-red-300/10' : 'border-current/30 opacity-60'}`}>
          🏮 家 {nostalgiaEntries.length}
        </button>
      </div>

      <div className="space-y-2 max-h-[55vh] overflow-y-auto pr-1">
        {entries.map((e, i) => {
          const ts = typeStyle[e.type];
          return (
            <details key={`${e.type}-${e.id}-${i}`} className="border border-current/20 p-3 group">
              <summary className="cursor-pointer flex items-center gap-2 text-sm">
                <span style={{ color: ts.color }}>{ts.icon}</span>
                <span className="flex-1">{e.title}</span>
                <span className="text-xs opacity-50" style={{ fontFamily: 'monospace' }}>{ts.label}</span>
              </summary>
              <div className="mt-3 pl-5 text-sm opacity-85 italic whitespace-pre-line border-l-2 border-current/20"
                style={{ lineHeight: '2', color: ts.color }}>
                {e.body}
              </div>
            </details>
          );
        })}
      </div>
    </div>
  );
}

function GroupChatView({ groupChat, addedStrangers }) {
  if (groupChat.length === 0) {
    return <div className="text-center opacity-50 italic py-12 text-sm">"伦敦留学生互助"群里还没人说话。</div>;
  }
  const allMembers = [...GROUP_MEMBERS, ...STRANGERS];
  const totalMembers = GROUP_MEMBERS.length + (addedStrangers?.length || 0);
  return (
    <div className="animate-fadein">
      <div className="text-xs tracking-[0.2em] opacity-60 mb-2 flex justify-between" style={{ fontFamily: 'monospace' }}>
        <span>👥 伦敦留学生互助 ({totalMembers})</span>
        <span className="opacity-50">{groupChat.length} 条消息</span>
      </div>
      <div className="space-y-2 max-h-[60vh] overflow-y-auto pr-1">
        {groupChat.map((m) => {
          const member = allMembers.find(g => g.id === m.from);
          if (!member) return null;
          return (
            <div key={m.id} className="flex gap-2 items-start animate-slidein">
              <div className="w-8 h-8 rounded-full flex items-center justify-center text-xs font-medium flex-shrink-0"
                style={{ background: member.color, color: '#1a1612' }}>{member.avatar}</div>
              <div className="flex-1 min-w-0">
                <div className="text-xs opacity-60 mb-0.5" style={{ fontFamily: 'monospace' }}>
                  {member.name} <span className="opacity-50">· W{m.week}</span>
                </div>
                <div className="text-sm bg-current/5 rounded-lg px-3 py-1.5 inline-block max-w-full break-words"
                     style={{ borderLeft: `2px solid ${member.color}40` }}>
                  {m.text}
                </div>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

function BirthdayPromptScreen({ onSelect }) {
  const months = [
    { num: 1, name: '一月' }, { num: 2, name: '二月' }, { num: 3, name: '三月' },
    { num: 4, name: '四月' }, { num: 5, name: '五月' }, { num: 6, name: '六月' },
    { num: 7, name: '七月' }, { num: 8, name: '八月' }, { num: 9, name: '九月' },
    { num: 10, name: '十月' }, { num: 11, name: '十一月' }, { num: 12, name: '十二月' },
  ];
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 animate-fadein"
      style={{ background: 'rgba(10, 8, 6, 0.95)' }}>
      <div className="bg-[#1a1612] border border-amber-300/40 max-w-md w-full p-6">
        <div className="text-xs tracking-[0.3em] opacity-50 mb-2" style={{ fontFamily: 'monospace' }}>BEFORE WE BEGIN</div>
        <h2 className="text-xl mb-3 font-light">你的生日是哪个月？</h2>
        <div className="text-sm opacity-80 italic mb-5" style={{ lineHeight: '1.7' }}>
          这一年里你会经历它一次。<br/>
          <span className="opacity-60">在异乡过的第一个生日，是会被记住的。</span>
        </div>
        <div className="grid grid-cols-3 gap-2">
          {months.map(m => (
            <button key={m.num} onClick={() => onSelect(m.num)}
              className="p-2.5 border border-current/40 hover:border-amber-300 hover:bg-amber-300/5 transition-all text-sm">
              {m.name}
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}

// ========================================
// Pret 点餐迷你游戏
// ========================================

function PretMinigame({ onComplete, onCancel }) {
  const [phase, setPhase] = useState('intro');
  const [currentQ, setCurrentQ] = useState(0);
  const [answers, setAnswers] = useState([]);
  const [showFeedback, setShowFeedback] = useState(null);

  function start() { audio.click(); setPhase('quiz'); }

  function answer(opt, optIdx) {
    audio.click();
    if (opt.correct) audio.success(); else audio.fail();
    setShowFeedback(opt);
    const newAns = [...answers, { q: currentQ, picked: optIdx, correct: opt.correct }];
    setAnswers(newAns);
  }

  function nextQ() {
    audio.click();
    setShowFeedback(null);
    if (currentQ + 1 < PRET_QUESTIONS.length) {
      setCurrentQ(currentQ + 1);
    } else {
      setPhase('done');
    }
  }

  function done() {
    audio.click();
    const correctCount = answers.filter(a => a.correct).length;
    const result = {
      score: correctCount,
      total: PRET_QUESTIONS.length,
      effect: {
        wallet: -5,
        energy: correctCount >= 4 ? 5 : -3,
        belonging: correctCount >= 4 ? 6 : correctCount >= 3 ? 2 : -3,
      },
      feedback: correctCount >= 4
        ? `你拿到咖啡走出 Pret，回头店员还在跟你笑。${correctCount}/5 答对——你这周第一次觉得，英语不再是一道墙。`
        : correctCount >= 3
        ? `你拿到了咖啡。咖啡比平时凉了一点，你猜是因为你站在那里太久了。${correctCount}/5。`
        : `你拿到了咖啡，但你在路上走了 5 分钟才想起这次的对话每一句都说得磕磕绊绊。${correctCount}/5。明天还得继续。`,
    };
    onComplete(result);
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 animate-fadein" style={{ background: 'rgba(10, 8, 6, 0.95)' }}>
      <div className="bg-[#1a1612] border border-current/40 max-w-md w-full p-5">
        <div className="text-xs tracking-[0.3em] opacity-50 mb-2" style={{ fontFamily: 'monospace' }}>☕ MINIGAME</div>
        <h2 className="text-xl mb-1 font-light">Pret 点餐</h2>
        <div className="text-xs opacity-60 italic mb-4" style={{ fontFamily: 'monospace' }}>5 句对话 · 你能听懂多少？</div>

        {phase === 'intro' && (
          <>
            <div className="text-sm opacity-90 mb-5" style={{ lineHeight: '1.85' }}>
              中午 12:30 的 Pret。后面排了 6 个英国人，他们都很赶时间。\n\n
              店员看着你："What can I get you, love?"
            </div>
            <button onClick={start} className="w-full py-3 border border-current hover:bg-current hover:text-black transition-colors tracking-[0.2em] text-sm">
              点单
            </button>
            <button onClick={onCancel} className="w-full mt-2 p-2 text-xs opacity-60 hover:opacity-100">逃出去 →</button>
          </>
        )}

        {phase === 'quiz' && !showFeedback && (
          <>
            <div className="text-xs opacity-60 mb-2" style={{ fontFamily: 'monospace' }}>第 {currentQ + 1} 句 / 共 5 句</div>
            <div className="border-l-2 border-current/50 pl-4 py-2 mb-4 italic text-base" style={{ lineHeight: '1.6' }}>
              <span className="opacity-60 text-xs not-italic mr-2">店员：</span>
              {PRET_QUESTIONS[currentQ].staff}
            </div>
            <div className="space-y-2">
              {PRET_QUESTIONS[currentQ].options.map((opt, i) => (
                <button key={i} onClick={() => answer(opt, i)}
                  className="w-full text-left p-3 border border-current/40 hover:border-current hover:bg-current/5 transition-all text-sm">
                  {opt.text}
                </button>
              ))}
            </div>
          </>
        )}

        {showFeedback && (
          <>
            <div className={`p-3 mb-4 border-l-2 italic text-sm ${showFeedback.correct ? 'border-green-400/60 text-green-200' : 'border-orange-400/60 text-orange-200'}`}
              style={{ lineHeight: '1.7' }}>
              {showFeedback.correct ? '✓ ' : '✗ '}{showFeedback.feedback}
            </div>
            <button onClick={nextQ} className="w-full py-2 border border-current text-sm tracking-[0.2em] hover:bg-current hover:text-black transition-colors">
              {currentQ + 1 < PRET_QUESTIONS.length ? 'NEXT' : '看结果'}
            </button>
          </>
        )}

        {phase === 'done' && (
          <>
            <div className="text-center my-6">
              <div className="text-xs opacity-60 mb-1" style={{ fontFamily: 'monospace' }}>YOUR SCORE</div>
              <div className="text-5xl font-light" style={{ fontFamily: 'monospace',
                color: answers.filter(a => a.correct).length >= 4 ? '#a0c890' : '#d4b070' }}>
                {answers.filter(a => a.correct).length}/{PRET_QUESTIONS.length}
              </div>
            </div>
            <button onClick={done} className="w-full py-2 border border-current text-sm tracking-[0.2em] hover:bg-current hover:text-black transition-colors">
              CONTINUE
            </button>
          </>
        )}
      </div>
    </div>
  );
}

// ========================================
// 论文写作迷你游戏
// ========================================

function EssayMinigame({ onComplete, onCancel }) {
  const [puzzleIdx, setPuzzleIdx] = useState(0);
  const [pickedIdx, setPickedIdx] = useState(null);
  const [score, setScore] = useState(0);
  const [showFb, setShowFb] = useState(null);

  const puzzle = ESSAY_PUZZLES[puzzleIdx];

  function pick(idx) {
    audio.click();
    setPickedIdx(idx);
    const opt = puzzle.options[idx];
    if (opt.correct) { audio.success(); setScore(score + 1); }
    else audio.fail();
    setShowFb(opt);
  }

  function next() {
    audio.click();
    setShowFb(null);
    setPickedIdx(null);
    if (puzzleIdx + 1 < ESSAY_PUZZLES.length) {
      setPuzzleIdx(puzzleIdx + 1);
    } else {
      finish();
    }
  }

  function finish() {
    audio.click();
    const finalScore = score + (showFb?.correct ? 0 : 0); // already counted
    onComplete({
      score: finalScore,
      total: ESSAY_PUZZLES.length,
      effect: {
        academic: finalScore * 4,
        energy: -8,
        belonging: finalScore >= 2 ? 3 : 0,
      },
      feedback: finalScore === 3
        ? '你写完这一段时已经凌晨 2 点。Whitmore 第二天看完邮件回了一句："This is publishable."'
        : finalScore >= 2
        ? '你写出来了。不完美，但每一句都是你自己的。Whitmore 写："Good progress."'
        : '你 4 个小时只写了一段，最后还是删了一半。但你坐下来过了——这就是写作的开始。',
    });
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 animate-fadein" style={{ background: 'rgba(10, 8, 6, 0.95)' }}>
      <div className="bg-[#1a1612] border border-purple-300/40 max-w-md w-full p-5">
        <div className="text-xs tracking-[0.3em] mb-1" style={{ fontFamily: 'monospace', color: '#9080b8' }}>📝 MINIGAME</div>
        <h2 className="text-xl mb-1 font-light">写论文</h2>
        <div className="text-xs opacity-60 italic mb-4" style={{ fontFamily: 'monospace' }}>填入最合适的句子 · {puzzleIdx + 1}/3</div>

        {!showFb ? (
          <>
            <div className="text-xs tracking-[0.2em] opacity-60 mb-2" style={{ fontFamily: 'monospace' }}>{puzzle.context}</div>
            <div className="border-l-2 border-purple-300/40 pl-4 py-2 mb-4 text-sm italic bg-purple-300/5"
              style={{ lineHeight: '1.85' }}>
              {puzzle.paragraph.split('___').map((part, i, arr) => (
                <span key={i}>
                  {part}
                  {i < arr.length - 1 && (
                    <span className="inline-block px-3 mx-1 py-0.5 border border-dashed border-purple-300/60 rounded text-xs opacity-80" style={{ color: '#9080b8' }}>
                      ?
                    </span>
                  )}
                </span>
              ))}
            </div>
            <div className="space-y-2">
              {puzzle.options.map((opt, i) => (
                <button key={i} onClick={() => pick(i)}
                  className="w-full text-left p-3 border border-current/40 hover:border-purple-300 hover:bg-purple-300/5 transition-all text-sm"
                  style={{ lineHeight: '1.6' }}>
                  {opt.text}
                </button>
              ))}
            </div>
            <button onClick={onCancel} className="w-full mt-3 p-2 text-xs opacity-60 hover:opacity-100">放弃 →</button>
          </>
        ) : (
          <>
            <div className={`p-3 mb-4 border-l-2 italic text-sm ${showFb.correct ? 'border-green-400/60' : 'border-orange-400/60'}`}
              style={{ lineHeight: '1.85' }}>
              {showFb.feedback}
            </div>
            <button onClick={next} className="w-full py-2 border border-current text-sm tracking-[0.2em] hover:bg-current hover:text-black transition-colors">
              {puzzleIdx + 1 < ESSAY_PUZZLES.length ? 'NEXT' : '完成'}
            </button>
          </>
        )}
      </div>
    </div>
  );
}

// ========================================
// 理论家概念匹配迷你游戏
// ========================================

function MatchMinigame({ onComplete, onCancel }) {
  // 每次随机抽 6 个概念
  const [round] = useState(() => {
    const allConcepts = Object.entries(THEORIST_MATCH.concepts);
    const shuffled = allConcepts.sort(() => Math.random() - 0.5).slice(0, 6);
    return shuffled.map(([id, c]) => ({ id, ...c }));
  });
  const [matched, setMatched] = useState({}); // { conceptId: theoristId }
  const [selectedConcept, setSelectedConcept] = useState(null);
  const [phase, setPhase] = useState('play'); // play | done

  function selectConcept(c) {
    if (matched[c.id]) return;
    audio.click();
    setSelectedConcept(c.id);
  }

  function selectTheorist(t) {
    if (!selectedConcept) return;
    audio.click();
    setMatched({ ...matched, [selectedConcept]: t.id });
    setSelectedConcept(null);
    if (Object.keys({ ...matched, [selectedConcept]: t.id }).length === round.length) {
      setTimeout(() => setPhase('done'), 300);
    }
  }

  function done() {
    audio.click();
    let correct = 0;
    Object.entries(matched).forEach(([cid, tid]) => {
      const theorist = THEORIST_MATCH.theorists.find(t => t.id === tid);
      if (theorist?.concepts.includes(cid)) correct++;
    });
    if (correct >= 5) audio.success(); else if (correct >= 3) audio.click(); else audio.fail();
    onComplete({
      score: correct,
      total: round.length,
      effect: {
        academic: correct * 2,
        energy: -5,
        belonging: correct >= 5 ? 3 : 0,
      },
      feedback: correct === 6
        ? `${correct}/6 全对。Aditi 路过看你的笔记本，竖了个大拇指："I knew you knew this stuff."`
        : correct >= 4
        ? `${correct}/6。算可以。这种基础知识是你的护城河。`
        : `${correct}/6。你看着自己写错的，意识到 reading list 不能再拖了。`,
    });
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 animate-fadein" style={{ background: 'rgba(10, 8, 6, 0.95)' }}>
      <div className="bg-[#1a1612] border border-blue-300/40 max-w-md w-full max-h-[90vh] overflow-y-auto p-5">
        <div className="text-xs tracking-[0.3em] mb-1" style={{ fontFamily: 'monospace', color: '#a0a0c8' }}>🎴 MINIGAME</div>
        <h2 className="text-xl mb-1 font-light">理论家与概念</h2>
        <div className="text-xs opacity-60 italic mb-4" style={{ fontFamily: 'monospace' }}>把概念匹配到对的人</div>

        {phase === 'play' && (
          <>
            <div className="text-xs opacity-60 mb-2" style={{ fontFamily: 'monospace' }}>
              {selectedConcept ? '选一个理论家 →' : '选一个概念 →'}
            </div>

            {/* 概念区 */}
            <div className="grid grid-cols-2 gap-2 mb-4">
              {round.map(c => {
                const isMatched = !!matched[c.id];
                const isSelected = selectedConcept === c.id;
                return (
                  <button key={c.id} onClick={() => selectConcept(c)} disabled={isMatched}
                    className={`p-2 border text-left transition-all ${
                      isMatched ? 'border-current/10 opacity-30' :
                      isSelected ? 'border-blue-300 bg-blue-300/10' :
                      'border-current/40 hover:border-current/70'
                    }`}>
                    <div className="text-sm">{c.label}</div>
                    <div className="text-xs opacity-60 italic">{c.desc}</div>
                  </button>
                );
              })}
            </div>

            {/* 理论家区 */}
            <div className="border-t border-current/20 pt-3">
              <div className="text-xs opacity-60 mb-2" style={{ fontFamily: 'monospace' }}>理论家</div>
              <div className="grid grid-cols-2 gap-2">
                {THEORIST_MATCH.theorists.map(t => {
                  const matchedToThis = Object.entries(matched).filter(([_, tid]) => tid === t.id).map(([cid]) => cid);
                  return (
                    <button key={t.id} onClick={() => selectTheorist(t)} disabled={!selectedConcept}
                      className={`p-2 border text-left transition-all ${
                        selectedConcept ? 'border-blue-300/60 hover:bg-blue-300/10' : 'border-current/30 opacity-50 cursor-not-allowed'
                      }`}>
                      <div className="text-sm font-medium">{t.name}</div>
                      {matchedToThis.length > 0 && (
                        <div className="text-xs opacity-60 italic mt-0.5">
                          {matchedToThis.map(cid => THEORIST_MATCH.concepts[cid]?.label).join(', ')}
                        </div>
                      )}
                    </button>
                  );
                })}
              </div>
            </div>
            <button onClick={onCancel} className="w-full mt-3 p-2 text-xs opacity-60 hover:opacity-100">先不玩 →</button>
          </>
        )}

        {phase === 'done' && (
          <>
            <div className="text-center my-4">
              <div className="text-xs opacity-60 mb-1" style={{ fontFamily: 'monospace' }}>SCORE</div>
              <div className="text-4xl font-light" style={{ fontFamily: 'monospace' }}>
                {Object.entries(matched).filter(([cid, tid]) => {
                  const t = THEORIST_MATCH.theorists.find(t2 => t2.id === tid);
                  return t?.concepts.includes(cid);
                }).length}/{round.length}
              </div>
            </div>
            <div className="space-y-1 text-xs mb-4">
              {Object.entries(matched).map(([cid, tid]) => {
                const concept = THEORIST_MATCH.concepts[cid];
                const theorist = THEORIST_MATCH.theorists.find(t => t.id === tid);
                const correct = theorist?.concepts.includes(cid);
                return (
                  <div key={cid} className={correct ? 'opacity-90' : 'opacity-60'}>
                    {correct ? '✓' : '✗'} {concept?.label} → {theorist?.name}
                  </div>
                );
              })}
            </div>
            <button onClick={done} className="w-full py-2 border border-current text-sm tracking-[0.2em] hover:bg-current hover:text-black transition-colors">
              CONTINUE
            </button>
          </>
        )}
      </div>
    </div>
  );
}


function TravelScreen({ destination, daysLeft, totalDays, events, allEvents, seenEvents,
  stats, onChooseEvent, onSkipDay, onFinish }) {

  const cityBg = {
    edinburgh: 'linear-gradient(180deg, #4a5568 0%, #2d3748 100%)',
    paris: 'linear-gradient(180deg, #d4a574 0%, #8b6f47 50%, #2d2520 100%)',
    amsterdam: 'linear-gradient(180deg, #5a8a70 0%, #2a4a3a 100%)',
    rome: 'linear-gradient(180deg, #d49060 0%, #7a4828 100%)',
  }[destination.id] || 'linear-gradient(180deg, #2a2520 0%, #1a1612 100%)';

  const dayUsed = totalDays - daysLeft + 1;

  return (
    <div className="fixed inset-0 z-40 flex items-center justify-center p-4 animate-fadein"
      style={{ background: cityBg }}>
      <div className="bg-[#1a1612]/95 border border-amber-300/40 max-w-md w-full max-h-[90vh] overflow-y-auto p-5 backdrop-blur">
        <div className="text-xs tracking-[0.4em] mb-1" style={{ fontFamily: 'monospace', color: '#d4b070' }}>
          ✈️ TRAVEL
        </div>
        <div className="flex justify-between items-baseline mb-3">
          <div>
            <h2 className="text-2xl font-light">{destination.name}</h2>
            <div className="text-xs opacity-60 italic" style={{ fontFamily: 'monospace' }}>{destination.desc}</div>
          </div>
          <div className="text-right">
            <div className="text-xs opacity-60" style={{ fontFamily: 'monospace' }}>DAY {dayUsed}/{totalDays}</div>
            <div className="flex gap-1 mt-1 justify-end">
              {[...Array(totalDays)].map((_, i) => (
                <div key={i} className={`w-2 h-2 rounded-full border ${i < totalDays - daysLeft + 1 ? 'bg-amber-300/80 border-amber-300' : 'border-current/30'}`} />
              ))}
            </div>
          </div>
        </div>

        {/* 已收集的明信片 */}
        {seenEvents.length > 0 && (
          <div className="mb-4 px-3 py-2 border border-amber-300/30 bg-amber-300/5">
            <div className="text-xs tracking-[0.2em] opacity-60 mb-1.5" style={{ fontFamily: 'monospace' }}>
              ✉️ POSTCARDS · {seenEvents.length}/{allEvents.length}
            </div>
            <div className="text-xs opacity-80 italic space-y-0.5">
              {allEvents.filter(e => seenEvents.includes(e.id) && e.postcard).map(e => (
                <div key={e.id}>· {e.postcard}</div>
              ))}
            </div>
          </div>
        )}

        <div className="text-xs tracking-[0.2em] opacity-60 mb-2" style={{ fontFamily: 'monospace' }}>今天做什么？</div>

        {events.length > 0 ? (
          <div className="space-y-2 mb-3">
            {events.map(ev => (
              <button key={ev.id} onClick={() => onChooseEvent(ev)}
                className="w-full text-left p-3 border border-current/40 hover:border-amber-300 hover:bg-amber-300/5 transition-all">
                <div className="text-sm">{ev.title}</div>
                <div className="text-xs opacity-60 italic mt-0.5 line-clamp-2">{ev.body.split('\n')[0]}</div>
              </button>
            ))}
          </div>
        ) : (
          <div className="text-sm opacity-70 italic mb-4">你已经看过了{destination.name}所有的角落。该回家了。</div>
        )}

        <div className="flex gap-2 mt-4">
          <button onClick={onSkipDay}
            className="flex-1 py-2 border border-current/40 text-sm hover:border-current transition-all">
            跳过今天 →
          </button>
          {(daysLeft <= 1 || events.length === 0) && (
            <button onClick={onFinish}
              className="flex-1 py-2 border border-amber-300/60 text-sm hover:bg-amber-300/10 transition-all"
              style={{ color: '#d4b070' }}>
              回伦敦 ✈️
            </button>
          )}
        </div>
      </div>
    </div>
  );
}

function TravelEventModal({ event, feedback, onChoose, onDismiss }) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 animate-fadein" style={{ background: 'rgba(10, 8, 6, 0.92)' }}>
      <div className="bg-[#1a1612] border border-amber-300/50 max-w-md w-full max-h-[90vh] overflow-y-auto p-5">
        <div className="text-xs tracking-[0.3em] mb-1" style={{ fontFamily: 'monospace', color: '#d4b070' }}>
          ✈️ TRAVEL EVENT
        </div>
        <h2 className="text-xl mb-3 font-light">{event.title}</h2>
        <div className="text-sm leading-relaxed mb-5 opacity-90 whitespace-pre-line" style={{ lineHeight: '1.85' }}>
          {event.body}
        </div>

        {!feedback ? (
          <>
            {(event.choices || [{
              label: event.title.length > 12 ? '继续' : `去${event.title}`,
              effect: event.effect || {},
              feedback: event.feedback || '...'
            }]).map((c, i) => (
              <button key={i} onClick={() => onChoose(c)}
                className="w-full text-left p-3 mb-2 border border-current/40 hover:border-amber-300 hover:bg-amber-300/5 transition-all">
                <span className="opacity-50 mr-2" style={{ fontFamily: 'monospace' }}>{String.fromCharCode(65 + i)}.</span>
                {c.label}
              </button>
            ))}
          </>
        ) : (
          <>
            <div className="border-l-2 border-amber-300/60 pl-4 py-1 mb-4 italic opacity-90 text-sm whitespace-pre-line" style={{ lineHeight: '1.85' }}>{feedback}</div>
            {event.postcard && (
              <div className="mb-4 px-3 py-2 border border-amber-300/40 bg-amber-300/5 text-center">
                <div className="text-xs opacity-60 mb-1" style={{ fontFamily: 'monospace' }}>✉️ NEW POSTCARD</div>
                <div className="text-sm italic" style={{ color: '#d4b070' }}>"{event.postcard}"</div>
              </div>
            )}
            <button onClick={onDismiss} className="w-full px-6 py-2 border border-current text-sm tracking-[0.2em] hover:bg-current hover:text-black transition-colors">
              CONTINUE
            </button>
          </>
        )}
      </div>
    </div>
  );
}

// 结局尾声 · 那些被你的选择记住的人
const ECHO_REVERBERATIONS = [
  // @你 事件回响
  { flagKey: 'kaize_friend', minVal: 5, npc: '凯泽', avatar: '凯', color: '#7a8a6a',
    text: '凯泽毕业前给你寄了一张手写卡片。"你不知道你那一通 1 小时电话救了我。我下个月去新加坡工作了。卡片随意放，重要的是你看到这一行字。"' },
  { flagKey: 'kaize_friend', minVal: 8, npc: '凯泽', avatar: '凯', color: '#7a8a6a',
    text: '凯泽收留你过的那张沙发，他后来真的扛回了国。"哥们 这沙发以后是我家的传家宝。" 你无奈地笑了。' },
  // 注：这里是简化版条件——实际游戏里 flag 是 boolean，所以我们还是用 flag 名称
];

function EndingScreen({ ending, stats, npcRel, attendanceRate, storyProgress, examResults, dissertationProgress, postcards, flags, addedStrangers, onRestart }) {

  // 根据 flag 生成回响段落
  const echoes = [];

  // 父母线 - 最重的回响放在最前
  if (flags?.parents_visited) {
    echoes.push({
      who: '爸妈', avatar: '家', color: '#d4b070',
      text: '你回国后第一次见到爸妈。妈妈一开门就说"瘦了瘦了 吃饭吃饭"。\n\n爸爸坐下来看你。看了 30 秒。然后说："这一年 你长大了。"\n\n你说："我看到你那次擦眼泪了。"\n\n他愣了一下。然后说："瞎说。" 然后他自己笑了。\n\n你妈端菜出来："还在那擦什么 吃饭。"\n\n你看着这一桌子菜。看着他们。\n\n你想：原来我留学这一年 是为了能看清楚我爸妈的样子。'
    });
  } else if (flags?.parents_declined) {
    echoes.push({
      who: '爸妈', avatar: '家', color: '#a89070',
      text: '毕业后你回国。第一晚和爸妈吃饭。\n\n你妈一直夹菜给你。爸爸在旁边喝汤。\n\n你突然说："那一年... 你们要是真的来 该多好。"\n\n你妈停下手："那时候你不让我们来。"\n\n你说"我知道。是我蠢。"\n\n你爸放下汤勺："下次。等你工作了 我们去看你。"\n\n下次没有真的来。但他说的"下次"你记着了。'
    });
  }

  if (flags?.kaize_friend) {
    echoes.push({
      who: '凯泽', avatar: '凯', color: '#7a8a6a',
      text: flags.kaize_friend
        ? '毕业半年后，你收到一张从新加坡寄来的手写卡片。\n\n"哥们/姐们 你不知道你那次帮我有多重要。我现在在新加坡上班了。这张卡片随便放。重要的是你看到这一行字：你救过我。"'
        : ''
    });
  }
  if (flags?.helped_xl) {
    echoes.push({
      who: '小李', avatar: '李', color: '#a87fb8',
      text: '一年后你刷到小红书。她已经 80 万粉丝。最新一条 vlog 末尾她说："这个频道开始的那个下午，有一个人陪我拍。我们没拍到 ta 的脸 但我永远记得那一天。" 评论区第一条："谁啊 求 cp"。\n\n你笑了，没回复。'
    });
  }
  if (flags?.aq_advised) {
    echoes.push({
      who: '阿强', avatar: '强', color: '#7a8a6a',
      text: '阿强真的结婚了。他给你寄了请柬——三亚。机票他报销。\n\n你犹豫了一周。最后你订了机票。\n\n婚礼那天他抱着你说："我一辈子记着你那次跟我说的话。"'
    });
  }
  if (flags?.tt_offer_dinner) {
    echoes.push({
      who: '婷婷', avatar: '婷', color: '#d4a4c0',
      text: '婷婷在 Goldman Sachs 入职前给你发了一条消息：\n\n"我下个月去香港 office 报到。如果你以后想跳金融 找我。我在 G 司给你内推。这不是客气。"\n\n你想：原来在伦敦认识一个人 三年后她可能就变成了你人生的一扇门。'
    });
  }
  if (flags?.helped_zhou) {
    echoes.push({
      who: '老周', avatar: '周', color: '#9a7050',
      text: '老周也毕业了。回国前他给你的快递箱里塞了一袋家乡茶叶 + 一封手写信。\n\n信里："小同学 你不知道你帮我改的那篇 essay 在我家是个传奇。我儿子现在跟同学说\'我爸 40 岁还能拿 distinction\'。这是你的功劳。"\n\n你把那袋茶喝了 1 年。'
    });
  }
  if (flags?.dj_marathon_cheer) {
    echoes.push({
      who: '大江', avatar: '江', color: '#c4615a',
      text: '大江把那块"加油"的牌子带回了国。后来他朋友圈发他儿子拿着那块牌子的照片。配文："这是爸爸 22 岁那年 一个朋友给我做的。爸爸希望你以后也有这样的朋友。"'
    });
  }
  if (flags?.lulu_painting) {
    echoes.push({
      who: '露露', avatar: '露', color: '#d4b070',
      text: '露露后来真的成了画家。她的第一次个展在伦敦 Soho。开幕邀请函只有 50 张。其中一张寄到了你北京的家。\n\n邀请函背面她手写："你是我画过最孤独的那幅画的第一个观众。"'
    });
  }
  if (flags?.phd_offer_open) {
    echoes.push({
      who: '上岸了的姐', avatar: '岸', color: '#9080b8',
      text: '你最后没去申请那个 PhD。但毕业 3 年后，上岸了的姐发来一条消息：\n\n"我们组又有 1 个 funded 名额。你现在准备好了吗？"\n\n你看了 1 小时这条消息。然后回："我准备一下。"'
    });
  }
  // 借钱 / 留宿等用 npc kaize_friend 来追踪 - 已在上面
  // 新生小王告别
  if (flags?.xiao_wang_goodbye) {
    echoes.push({
      who: '新生小王', avatar: '王', color: '#d4b070',
      text: '新生小王回国后没怎么联系。但有一天他突然给你寄了一封信——纸是他自己折的。\n\n"哥/姐 我现在国内一家小公司上班。挺好的。我有时候还会想伦敦。但 我没后悔。\n\n谢谢你那次去 Pret 见我。我就是想跟一个人吃顿饭再走。是你来了。"'
    });
  }

  return (
    <div className="animate-fadein-slow max-w-2xl mx-auto pt-12 pb-8">
      <div className="text-xs tracking-[0.4em] opacity-50 mb-3" style={{ fontFamily: 'monospace' }}>ENDING · {ending.subtitle.toUpperCase()}</div>
      <h2 className="text-5xl mb-2 font-light">{ending.title}</h2>
      <div className="text-sm opacity-60 italic mb-10">{ending.subtitle}</div>
      <div className="text-base leading-relaxed mb-10 opacity-90 whitespace-pre-line" style={{ lineHeight: '2' }}>{ending.text}</div>

      {echoes.length > 0 && (
        <div className="border-t border-current/20 pt-6 mb-6">
          <div className="text-xs tracking-[0.3em] opacity-50 mb-4" style={{ fontFamily: 'monospace' }}>📮 那些没忘记的人</div>
          <div className="space-y-5">
            {echoes.map((e, i) => (
              <div key={i} className="flex gap-3 items-start">
                <div className="w-8 h-8 rounded-full flex items-center justify-center text-xs font-medium flex-shrink-0"
                  style={{ background: e.color, color: '#1a1612' }}>{e.avatar}</div>
                <div className="flex-1">
                  <div className="text-xs opacity-60 mb-1.5" style={{ fontFamily: 'monospace' }}>· {e.who} ·</div>
                  <div className="text-sm italic opacity-90 whitespace-pre-line" style={{ lineHeight: '1.95' }}>
                    {e.text}
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      <div className="border-t border-current/20 pt-6 mb-6 space-y-4">
        <div>
          <div className="text-xs tracking-[0.3em] opacity-50 mb-2" style={{ fontFamily: 'monospace' }}>FINAL STATS</div>
          <div className="grid grid-cols-5 gap-2 text-xs">
            <div><div className="opacity-60">学业</div><div style={{ fontFamily: 'monospace' }}>{stats.academic}%</div></div>
            <div><div className="opacity-60">钱包</div><div style={{ fontFamily: 'monospace' }}>£{stats.wallet}</div></div>
            <div><div className="opacity-60">精力</div><div style={{ fontFamily: 'monospace' }}>{stats.energy}%</div></div>
            <div><div className="opacity-60">归属</div><div style={{ fontFamily: 'monospace' }}>{stats.belonging}%</div></div>
            <div><div className="opacity-60">出勤</div><div style={{ fontFamily: 'monospace' }}>{attendanceRate}%</div></div>
          </div>
        </div>

        {examResults && Object.keys(examResults).length > 0 && (
          <div>
            <div className="text-xs tracking-[0.3em] opacity-50 mb-2" style={{ fontFamily: 'monospace' }}>EXAMS</div>
            <div className="grid grid-cols-3 gap-2 text-xs">
              {Object.entries(examResults).map(([id, score]) => {
                const exam = EXAM_PAPERS.find(e => e.id === id);
                return (
                  <div key={id}>
                    <div className="opacity-60">{exam?.cn || id}</div>
                    <div style={{ fontFamily: 'monospace', color: score >= 70 ? '#a0c890' : score >= 50 ? '#d4b070' : '#c86060' }}>{score}%</div>
                  </div>
                );
              })}
            </div>
          </div>
        )}

        {dissertationProgress > 0 && (
          <div>
            <div className="text-xs tracking-[0.3em] opacity-50 mb-2" style={{ fontFamily: 'monospace' }}>DISSERTATION</div>
            <div className="text-xs" style={{ fontFamily: 'monospace' }}>完成度 {dissertationProgress}%</div>
          </div>
        )}

        <div>
          <div className="text-xs tracking-[0.3em] opacity-50 mb-2" style={{ fontFamily: 'monospace' }}>STORIES UNLOCKED</div>
          <div className="space-y-1 text-xs">
            {Object.values(STORYLINES).map(line => (
              <div key={line.id} className="flex justify-between">
                <span>{line.name}</span>
                <span style={{ fontFamily: 'monospace' }}>{storyProgress[line.id] || 0} / {line.chapters.length}</span>
              </div>
            ))}
          </div>
        </div>

        {postcards && postcards.length > 0 && (
          <div>
            <div className="text-xs tracking-[0.3em] opacity-50 mb-2" style={{ fontFamily: 'monospace' }}>✉️ POSTCARDS · {postcards.length}</div>
            <div className="space-y-1 text-xs italic opacity-80">
              {postcards.map(p => (
                <div key={p.id}>{p.text}</div>
              ))}
            </div>
          </div>
        )}
      </div>

      <button onClick={onRestart} className="px-12 py-3 border border-current tracking-[0.3em] text-sm hover:bg-current hover:text-black transition-colors duration-500">AGAIN</button>
      <div className="mt-12 text-xs opacity-30 italic text-center">每一次重来都是不同的人生。</div>
    </div>
  );
}

function clamp(v, min, max) { return Math.max(min, Math.min(max, v)); }
