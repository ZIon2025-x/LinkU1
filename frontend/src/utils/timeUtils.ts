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
      console.warn('DST检测失败:', error);
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
      } else if (utcTimeString.includes('T')) {
        // ISO格式但没有Z后缀
        utcTime = dayjs.utc(utcTimeString + 'Z');
      } else {
        // 数据库格式：'2025-10-18 05:28:03.841934'，假设是UTC时间
        utcTime = dayjs.utc(utcTimeString);
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
      
      console.log('formatLastMessageTime 调试信息:');
      console.log('输入时间字符串:', utcTimeString);
      console.log('用户时区:', tz);
      
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
      
      console.log('解析后UTC时间:', utcTime.format());
      
      // 转换为用户时区
      const messageTime = utcTime.tz(tz);
      const now = dayjs().tz(tz);
      
      console.log('用户时区时间:', messageTime.format());
      console.log('当前时间:', now.format());
      
      // 计算时间差
      const diffInMinutes = now.diff(messageTime, 'minute');
      const diffInHours = now.diff(messageTime, 'hour');
      const diffInDays = now.diff(messageTime, 'day');
      
      console.log(`时间差: ${diffInMinutes}分钟, ${diffInHours}小时, ${diffInDays}天`);
      
      // 根据时间差显示不同格式
      let result;
      if (diffInMinutes < 1) {
        result = '刚刚';
      } else if (diffInMinutes < 60) {
        result = `${diffInMinutes}分钟前`;
      } else if (diffInHours < 24) {
        result = `${diffInHours}小时前`;
      } else if (diffInDays < 7) {
        result = `${diffInDays}天前`;
      } else {
        result = messageTime.format('MM/DD');
      }
      
      console.log('最终结果:', result);
      return result;
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
