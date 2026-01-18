/**
 * 统一时间处理工具 v2.0
 * 所有时间统一从UTC转换为用户本地时间显示
 */
import dayjs from 'dayjs';
import utc from 'dayjs/plugin/utc';
import timezone from 'dayjs/plugin/timezone';

// 配置dayjs插件
dayjs.extend(utc);
dayjs.extend(timezone);

export interface TimezoneInfo {
  server_timezone: string;
  server_time: string;
  utc_time: string;
  timezone_offset: string;
  is_dst: boolean;
  timezone_name: string;
}

export class TimeHandlerV2 {
  /**
   * 获取用户本地时区
   */
  static getUserTimezone(): string {
    try {
      return Intl.DateTimeFormat().resolvedOptions().timeZone;
    } catch (error) {
      // 静默处理错误
      return 'Europe/London'; // 默认英国时区
    }
  }

  /**
   * 检查是否为夏令时（DST）
   * @param dayjsTime dayjs时间对象
   * @param timezone 时区
   */
  private static isDST(dayjsTime: any, timezone: string): boolean {
    try {
      if (timezone === 'Europe/London') {
        // 对于英国时区，通过UTC偏移量判断
        const utcOffset = dayjsTime.utcOffset();
        return utcOffset === 60; // BST是UTC+1，即60分钟偏移
      }
      
      // 对于其他时区，使用dayjs的时区信息
      const utcOffset = dayjsTime.utcOffset();
      const standardOffset = dayjsTime.tz(timezone).utcOffset();
      
      // 如果当前偏移量大于标准偏移量，说明是夏令时
      return utcOffset > standardOffset;
    } catch (error) {
            return false;
    }
  }

  /**
   * 格式化UTC时间为用户本地时间显示
   * @param utcTimeString UTC时间字符串
   * @param format 显示格式，默认 'YYYY/MM/DD HH:mm:ss'
   * @param userTimezone 用户时区，可选，默认自动检测
   */
  static formatUtcToLocal(
    utcTimeString: string, 
    format: string = 'YYYY/MM/DD HH:mm:ss',
    userTimezone?: string
  ): string {
    try {
      const tz = userTimezone || this.getUserTimezone();
      
      // 确保正确解析UTC时间
      let utcTime;
      
      // 处理不同的时间格式
      if (utcTimeString.endsWith('Z')) {
        // 标准ISO格式，带Z后缀
        utcTime = dayjs.utc(utcTimeString);
      } else if (utcTimeString.match(/[+-]\d{2}:?\d{2}$/)) {
        // ISO格式带时区偏移（如 +00:00 或 +00）
        // 将时区偏移转换为Z（UTC）
        const normalized = utcTimeString.replace(/[+-]\d{2}:?\d{2}$/, 'Z');
        utcTime = dayjs.utc(normalized);
      } else if (utcTimeString.includes('T')) {
        // ISO格式但没有Z后缀，假设是UTC时间
        utcTime = dayjs.utc(utcTimeString + 'Z');
      } else {
        // 数据库格式：'2025-10-18 05:28:03.841934'，假设是UTC时间
        // 或者带时区的格式：'2025-11-24 02:01:31.575514+00'
        if (utcTimeString.match(/[+-]\d{2}$/)) {
          // 带时区偏移的数据库格式（如 +00）
          const normalized = utcTimeString.replace(/[+-]\d{2}$/, '').replace(' ', 'T') + 'Z';
          utcTime = dayjs.utc(normalized);
        } else {
          // 纯数据库格式，假设是UTC时间
          utcTime = dayjs.utc(utcTimeString.replace(' ', 'T') + 'Z');
        }
      }
      
      // 检查日期是否有效
      if (!utcTime.isValid()) {
                return utcTimeString; // 返回原始字符串
      }
      
      // 转换为用户时区
      const localTime = utcTime.tz(tz);
      
      // 如果是英国时区，检查DST并添加时区标识
      if (tz === 'Europe/London') {
        const isDST = this.isDST(localTime, tz);
        const tzName = isDST ? 'BST' : 'GMT';
        return `${localTime.format(format)} (${tzName})`;
      }
      
      return localTime.format(format);
    } catch (error) {
            return utcTimeString; // 返回原始字符串作为fallback
    }
  }

  /**
   * 格式化消息时间（短格式）
   * @param utcTimeString UTC时间字符串
   * @param userTimezone 用户时区
   */
  static formatMessageTime(
    utcTimeString: string, 
    userTimezone?: string
  ): string {
    return this.formatUtcToLocal(utcTimeString, 'HH:mm', userTimezone);
  }

  /**
   * 格式化最后消息时间（智能格式）
   * @param utcTimeString UTC时间字符串
   * @param userTimezone 用户时区
   * @param t 翻译函数（可选）
   */
  static formatLastMessageTime(
    utcTimeString: string | null, 
    userTimezone?: string,
    t?: (key: string, params?: any) => string
  ): string {
    if (!utcTimeString) return '';
    
    try {
      const tz = userTimezone || this.getUserTimezone();
      
      // 确保正确解析UTC时间
      let utcTime;
      
      // 处理不同的时间格式
      if (utcTimeString.endsWith('Z')) {
        // 标准ISO格式，带Z后缀
        utcTime = dayjs.utc(utcTimeString);
      } else if (utcTimeString.includes('T')) {
        // ISO格式但没有Z后缀
        utcTime = dayjs.utc(utcTimeString + 'Z');
      } else {
        // 数据库格式：'2025-10-18 05:28:03.841934'，假设是UTC时间
        utcTime = dayjs.utc(utcTimeString);
      }
      
      // 转换为英国时间进行比较
      const messageTimeUK = utcTime.tz('Europe/London');
      const nowUK = dayjs().tz('Europe/London');
      
      // 计算时间差（使用英国时间）
      const diffInMinutes = nowUK.diff(messageTimeUK, 'minute');
      const diffInHours = nowUK.diff(messageTimeUK, 'hour');
      const diffInDays = nowUK.diff(messageTimeUK, 'day');
      
      // 根据时间差显示不同格式
      if (t) {
        // 使用翻译函数
        if (diffInMinutes < 1) {
          return t('time.justNow');
        } else if (diffInMinutes < 60) {
          return t('time.minutesAgo', { count: diffInMinutes });
        } else if (diffInHours < 24) {
          return t('time.hoursAgo', { count: diffInHours });
        } else if (diffInDays < 7) {
          return t('time.daysAgo', { count: diffInDays });
        } else {
          return messageTimeUK.format('MM/DD');
        }
      } else {
        // 如果没有翻译函数，使用英文
        if (diffInMinutes < 1) {
          return 'Just now';
        } else if (diffInMinutes < 60) {
          return `${diffInMinutes} minutes ago`;
        } else if (diffInHours < 24) {
          return `${diffInHours} hours ago`;
        } else if (diffInDays < 7) {
          return `${diffInDays} days ago`;
        } else {
          return messageTimeUK.format('MM/DD');
        }
      }
    } catch (error) {
            return utcTimeString;
    }
  }

  /**
   * 格式化详细时间（带时区信息）
   * @param utcTimeString UTC时间字符串
   * @param userTimezone 用户时区
   * @param t 翻译函数（可选）
   */
  static formatDetailedTime(
    utcTimeString: string, 
    userTimezone?: string,
    t?: (key: string) => string
  ): string {
    try {
      const tz = userTimezone || this.getUserTimezone();
      
      // 确保正确解析UTC时间
      let utcTime;
      
      // 处理不同的时间格式
      if (utcTimeString.endsWith('Z')) {
        // 标准ISO格式，带Z后缀
        utcTime = dayjs.utc(utcTimeString);
      } else if (utcTimeString.includes('T')) {
        // ISO格式但没有Z后缀
        utcTime = dayjs.utc(utcTimeString + 'Z');
      } else {
        // 数据库格式：'2025-10-18 05:28:03.841934'，假设是UTC时间
        utcTime = dayjs.utc(utcTimeString);
      }
      
      // 转换为用户时区
      const localTime = utcTime.tz(tz);
      
      // 检查是否夏令时
      const isDST = this.isDST(localTime, tz);
      let tzDisplay;
      
      if (tz === 'Europe/London') {
        if (t) {
          // 使用翻译函数
          tzDisplay = isDST ? t('time.bst') : t('time.gmt');
        } else {
          // 如果没有翻译函数，使用英文缩写
          tzDisplay = isDST ? 'BST' : 'GMT';
        }
      } else {
        tzDisplay = tz;
      }
      
      return `${localTime.format('YYYY/MM/DD HH:mm:ss')} (${tzDisplay})`;
    } catch (error) {
            return utcTimeString;
    }
  }

  /**
   * 获取时区信息
   */
  static async getTimezoneInfo(): Promise<TimezoneInfo | null> {
    try {
      const response = await api.get('/api/users/timezone/info');
      return response.data;
    } catch (error) {
      return null;
    }
  }

  /**
   * 比较两个UTC时间
   * @param utcTime1 第一个UTC时间字符串
   * @param utcTime2 第二个UTC时间字符串
   * @returns 比较结果：-1, 0, 1
   */
  static compareUtcTimes(utcTime1: string, utcTime2: string): number {
    try {
      const time1 = dayjs.utc(utcTime1.endsWith('Z') ? utcTime1 : utcTime1 + 'Z');
      const time2 = dayjs.utc(utcTime2.endsWith('Z') ? utcTime2 : utcTime2 + 'Z');
      
      if (time1.isBefore(time2)) return -1;
      if (time1.isAfter(time2)) return 1;
      return 0;
    } catch (error) {
            return 0;
    }
  }
}

/**
 * 格式化相对时间（用于论坛等场景）
 * @param utcTimeString UTC时间字符串
 * @param userTimezone 用户时区
 * @returns 相对时间字符串（如"2小时前"、"3天前"等）
 */
export function formatRelativeTime(
  utcTimeString: string | null | undefined,
  userTimezone?: string
): string {
  if (!utcTimeString) return '';
  
  try {
    const tz = userTimezone || TimeHandlerV2.getUserTimezone();
    
    // 确保正确解析UTC时间
    let utcTime;
    
    // 处理不同的时间格式
    if (utcTimeString.endsWith('Z')) {
      // 标准ISO格式，带Z后缀
      utcTime = dayjs.utc(utcTimeString);
    } else if (utcTimeString.includes('T')) {
      // ISO格式但没有Z后缀
      utcTime = dayjs.utc(utcTimeString + 'Z');
    } else {
      // 数据库格式：'2025-10-18 05:28:03.841934'，假设是UTC时间
      utcTime = dayjs.utc(utcTimeString);
    }
    
    // 转换为用户时区
    const localTime = utcTime.tz(tz);
    const now = dayjs().tz(tz);
    
    // 计算时间差
    const diffInSeconds = now.diff(localTime, 'second');
    const diffInMinutes = now.diff(localTime, 'minute');
    const diffInHours = now.diff(localTime, 'hour');
    const diffInDays = now.diff(localTime, 'day');
    const diffInWeeks = now.diff(localTime, 'week');
    const diffInMonths = now.diff(localTime, 'month');
    const diffInYears = now.diff(localTime, 'year');
    
    // 根据时间差显示不同格式
    if (diffInSeconds < 60) {
      return '刚刚';
    } else if (diffInMinutes < 60) {
      return `${diffInMinutes}分钟前`;
    } else if (diffInHours < 24) {
      return `${diffInHours}小时前`;
    } else if (diffInDays < 7) {
      return `${diffInDays}天前`;
    } else if (diffInWeeks < 4) {
      return `${diffInWeeks}周前`;
    } else if (diffInMonths < 12) {
      return `${diffInMonths}个月前`;
    } else if (diffInYears < 1) {
      return localTime.format('MM-DD');
    } else {
      return localTime.format('YYYY-MM-DD');
    }
  } catch (error) {
        return utcTimeString;
  }
}

// 导出便捷函数
export const formatUtcToLocal = TimeHandlerV2.formatUtcToLocal.bind(TimeHandlerV2);
export const formatMessageTime = TimeHandlerV2.formatMessageTime.bind(TimeHandlerV2);
export const formatLastMessageTime = TimeHandlerV2.formatLastMessageTime.bind(TimeHandlerV2);
export const formatDetailedTime = TimeHandlerV2.formatDetailedTime.bind(TimeHandlerV2);
export const getTimezoneInfo = TimeHandlerV2.getTimezoneInfo.bind(TimeHandlerV2);
