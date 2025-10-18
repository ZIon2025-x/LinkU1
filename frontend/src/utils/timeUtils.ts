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
      console.warn('无法检测用户时区，使用默认值:', error);
      return 'Europe/London'; // 默认英国时区
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
      if (utcTimeString.endsWith('Z')) {
        // 已经是标准UTC格式
        utcTime = dayjs.utc(utcTimeString);
      } else {
        // 假设是UTC时间，添加Z后缀
        utcTime = dayjs.utc(utcTimeString + 'Z');
      }
      
      // 转换为用户时区
      const localTime = utcTime.tz(tz);
      
      // 如果是英国时区，检查DST并添加时区标识
      if (tz === 'Europe/London') {
        const isDST = localTime.isDST();
        const tzName = isDST ? 'BST' : 'GMT';
        return `${localTime.format(format)} (${tzName})`;
      }
      
      return localTime.format(format);
    } catch (error) {
      console.error('时间格式化错误:', error);
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
   */
  static formatLastMessageTime(
    utcTimeString: string | null, 
    userTimezone?: string
  ): string {
    if (!utcTimeString) return '';
    
    try {
      const tz = userTimezone || this.getUserTimezone();
      const now = dayjs();
      const messageTime = this.formatUtcToLocal(utcTimeString, '', tz);
      const messageDayjs = dayjs.tz(messageTime, tz);
      
      const diffInHours = now.diff(messageDayjs, 'hour');
      
      if (diffInHours < 24) {
        return messageDayjs.format('HH:mm');
      } else if (diffInHours < 168) { // 7 days
        return messageDayjs.format('ddd');
      } else {
        return messageDayjs.format('MM/DD');
      }
    } catch (error) {
      console.error('最后消息时间格式化错误:', error);
      return utcTimeString;
    }
  }

  /**
   * 格式化详细时间（带时区信息）
   * @param utcTimeString UTC时间字符串
   * @param userTimezone 用户时区
   */
  static formatDetailedTime(
    utcTimeString: string, 
    userTimezone?: string
  ): string {
    try {
      const tz = userTimezone || this.getUserTimezone();
      
      // 确保正确解析UTC时间
      let utcTime;
      if (utcTimeString.endsWith('Z')) {
        utcTime = dayjs.utc(utcTimeString);
      } else {
        utcTime = dayjs.utc(utcTimeString + 'Z');
      }
      
      // 转换为用户时区
      const localTime = utcTime.tz(tz);
      
      // 检查是否夏令时
      const isDST = localTime.isDST();
      let tzDisplay;
      
      if (tz === 'Europe/London') {
        tzDisplay = isDST ? 'BST (英国夏令时)' : 'GMT (英国冬令时)';
      } else {
        tzDisplay = tz;
      }
      
      return `${localTime.format('YYYY/MM/DD HH:mm:ss')} (${tzDisplay})`;
    } catch (error) {
      console.error('详细时间格式化错误:', error);
      return utcTimeString;
    }
  }

  /**
   * 获取时区信息
   */
  static async getTimezoneInfo(): Promise<TimezoneInfo | null> {
    try {
      const response = await fetch('/api/users/timezone/info');
      return await response.json();
    } catch (error) {
      console.error('获取时区信息失败:', error);
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
      console.error('时间比较错误:', error);
      return 0;
    }
  }
}

// 导出便捷函数
export const formatUtcToLocal = TimeHandlerV2.formatUtcToLocal.bind(TimeHandlerV2);
export const formatMessageTime = TimeHandlerV2.formatMessageTime.bind(TimeHandlerV2);
export const formatLastMessageTime = TimeHandlerV2.formatLastMessageTime.bind(TimeHandlerV2);
export const formatDetailedTime = TimeHandlerV2.formatDetailedTime.bind(TimeHandlerV2);
export const getTimezoneInfo = TimeHandlerV2.getTimezoneInfo.bind(TimeHandlerV2);
