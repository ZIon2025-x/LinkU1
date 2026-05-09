export const WEATHERS = {
  sunny: { id: 'sunny', cn: '晴', emoji: '☀️', energyMod: 0, exploreMod: 2, desc: '伦敦罕见的晴天' },
  cloudy: { id: 'cloudy', cn: '多云', emoji: '☁️', energyMod: 0, exploreMod: 0, desc: '灰白的天' },
  drizzle: { id: 'drizzle', cn: '小雨', emoji: '🌧️', energyMod: -1, exploreMod: -1, desc: '伦敦标配' },
  rain: { id: 'rain', cn: '大雨', emoji: '⛈️', energyMod: -3, exploreMod: -3, desc: '不想出门' },
  fog: { id: 'fog', cn: '雾', emoji: '🌫️', energyMod: -1, exploreMod: 0, desc: '雾里看不见对面的人' },
  snow: { id: 'snow', cn: '雪', emoji: '❄️', energyMod: -2, exploreMod: 4, desc: '伦敦少见的雪' },
};

export function generateWeekWeather(week, rng = Math.random) {
  const winterWeeks = [9, 10, 11, 12, 13, 14, 15, 16];
  const springWeeks = [17, 18, 19, 20, 21, 22, 23, 24, 25, 26];
  const summerWeeks = [27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38];
  const r = rng();

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

export const WEATHER_EVENTS = [
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
