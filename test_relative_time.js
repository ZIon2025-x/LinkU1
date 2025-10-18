// 测试相对时间显示
const dayjs = require('dayjs');
const utc = require('dayjs/plugin/utc');
const timezone = require('dayjs/plugin/timezone');

dayjs.extend(utc);
dayjs.extend(timezone);

function formatLastMessageTime(utcTimeString, userTimezone = 'Europe/London') {
  if (!utcTimeString) return '';
  
  try {
    // 确保正确解析UTC时间
    let utcTime;
    if (utcTimeString.endsWith('Z')) {
      utcTime = dayjs.utc(utcTimeString);
    } else {
      utcTime = dayjs.utc(utcTimeString + 'Z');
    }
    
    // 转换为用户时区
    const messageTime = utcTime.tz(userTimezone);
    const now = dayjs().tz(userTimezone);
    
    // 计算时间差
    const diffInMinutes = now.diff(messageTime, 'minute');
    const diffInHours = now.diff(messageTime, 'hour');
    const diffInDays = now.diff(messageTime, 'day');
    
    console.log(`UTC时间: ${utcTimeString}`);
    console.log(`解析后UTC时间: ${utcTime.format()}`);
    console.log(`用户时区时间: ${messageTime.format()}`);
    console.log(`当前时间: ${now.format()}`);
    console.log(`时间差: ${diffInMinutes}分钟, ${diffInHours}小时, ${diffInDays}天`);
    
    // 根据时间差显示不同格式
    if (diffInMinutes < 1) {
      return '刚刚';
    } else if (diffInMinutes < 60) {
      return `${diffInMinutes}分钟前`;
    } else if (diffInHours < 24) {
      return `${diffInHours}小时前`;
    } else if (diffInDays < 7) {
      return `${diffInDays}天前`;
    } else {
      return messageTime.format('MM/DD');
    }
  } catch (error) {
    console.error('最后消息时间格式化错误:', error);
    return utcTimeString;
  }
}

// 测试不同时间
console.log('=== 测试相对时间显示 ===\n');

// 测试几分钟前
const now = new Date();
const fewMinutesAgo = new Date(now.getTime() - 5 * 60 * 1000); // 5分钟前
console.log('测试5分钟前:');
console.log('结果:', formatLastMessageTime(fewMinutesAgo.toISOString()));
console.log('');

// 测试1小时前
const oneHourAgo = new Date(now.getTime() - 60 * 60 * 1000); // 1小时前
console.log('测试1小时前:');
console.log('结果:', formatLastMessageTime(oneHourAgo.toISOString()));
console.log('');

// 测试刚刚
const justNow = new Date(now.getTime() - 30 * 1000); // 30秒前
console.log('测试30秒前:');
console.log('结果:', formatLastMessageTime(justNow.toISOString()));
console.log('');

// 测试数据库格式的时间字符串
const dbTimeString = now.toISOString().replace('Z', ''); // 模拟数据库格式
console.log('测试数据库格式时间:');
console.log('结果:', formatLastMessageTime(dbTimeString));
