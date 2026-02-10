import 'package:intl/intl.dart';
import '../../l10n/app_localizations.dart';

/// 日期格式化工具
/// 参考iOS DateFormatterHelper.swift
class DateFormatter {
  DateFormatter._();

  // ==================== 格式化器 ====================
  static final DateFormat _fullDate = DateFormat('yyyy-MM-dd HH:mm:ss');
  static final DateFormat _date = DateFormat('yyyy-MM-dd');
  static final DateFormat _time = DateFormat('HH:mm');
  static final DateFormat _dateTime = DateFormat('yyyy-MM-dd HH:mm');
  static final DateFormat _monthDay = DateFormat('MM-dd');
  static final DateFormat _yearMonth = DateFormat('yyyy-MM');
  static final DateFormat _weekday = DateFormat('EEEE');
  static final DateFormat _shortWeekday = DateFormat('EEE');

  // ==================== 格式化方法 ====================
  /// 完整日期时间
  static String formatFull(DateTime date) => _fullDate.format(date);

  /// 日期
  static String formatDate(DateTime date) => _date.format(date);

  /// 时间
  static String formatTime(DateTime date) => _time.format(date);

  /// 日期时间
  static String formatDateTime(DateTime date) => _dateTime.format(date);

  /// 月日
  static String formatMonthDay(DateTime date) => _monthDay.format(date);

  /// 年月
  static String formatYearMonth(DateTime date) => _yearMonth.format(date);

  /// 星期几
  static String formatWeekday(DateTime date) => _weekday.format(date);

  /// 短星期几
  static String formatShortWeekday(DateTime date) => _shortWeekday.format(date);

  // ==================== 智能格式化 ====================
  /// 智能时间显示（几分钟前、几小时前、昨天、日期）
  static String formatSmart(DateTime date,
      {bool showTime = false, AppLocalizations? l10n}) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) {
      return l10n?.timeJustNow ?? 'Just now';
    } else if (diff.inMinutes < 60) {
      return l10n?.timeMinutesAgo(diff.inMinutes) ?? '${diff.inMinutes} min ago';
    } else if (diff.inHours < 24) {
      return l10n?.timeHoursAgo(diff.inHours) ?? '${diff.inHours} hr ago';
    } else if (diff.inDays == 1) {
      final yesterday = l10n?.timeYesterday ?? 'Yesterday';
      return showTime ? '$yesterday ${formatTime(date)}' : yesterday;
    } else if (diff.inDays == 2) {
      final dayBefore =
          l10n?.timeDayBeforeYesterday ?? 'Day before yesterday';
      return showTime ? '$dayBefore ${formatTime(date)}' : dayBefore;
    } else if (diff.inDays < 7) {
      return showTime
          ? '${formatShortWeekday(date)} ${formatTime(date)}'
          : formatShortWeekday(date);
    } else if (date.year == now.year) {
      return showTime
          ? '${formatMonthDay(date)} ${formatTime(date)}'
          : formatMonthDay(date);
    } else {
      return showTime ? formatDateTime(date) : formatDate(date);
    }
  }

  /// 消息时间格式化
  static String formatMessageTime(DateTime date, {AppLocalizations? l10n}) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) {
      return l10n?.timeJustNow ?? 'Just now';
    } else if (diff.inHours < 1) {
      return l10n?.timeMinutesAgo(diff.inMinutes) ?? '${diff.inMinutes} min ago';
    } else if (_isSameDay(date, now)) {
      return formatTime(date);
    } else if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
      final yesterday = l10n?.timeYesterday ?? 'Yesterday';
      return '$yesterday ${formatTime(date)}';
    } else if (diff.inDays < 7) {
      return '${formatShortWeekday(date)} ${formatTime(date)}';
    } else if (date.year == now.year) {
      return '${formatMonthDay(date)} ${formatTime(date)}';
    } else {
      return formatDateTime(date);
    }
  }

  /// 截止时间格式化
  static String formatDeadline(DateTime deadline, {AppLocalizations? l10n}) {
    final now = DateTime.now();
    final diff = deadline.difference(now);

    if (diff.isNegative) {
      return l10n?.timeExpired ?? 'Expired';
    } else if (diff.inHours < 1) {
      return l10n?.timeDeadlineMinutes(diff.inMinutes) ??
          'Due in ${diff.inMinutes} min';
    } else if (diff.inHours < 24) {
      return l10n?.timeDeadlineHours(diff.inHours) ??
          'Due in ${diff.inHours} hr';
    } else if (diff.inDays < 7) {
      return l10n?.timeDeadlineDays(diff.inDays) ??
          'Due in ${diff.inDays} days';
    } else {
      return l10n?.timeDeadlineDate(formatDate(deadline)) ??
          '${formatDate(deadline)} due';
    }
  }

  /// 倒计时格式化
  static String formatCountdown(Duration duration) {
    if (duration.isNegative) {
      return '00:00:00';
    }

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
  }

  // ==================== 解析方法 ====================
  /// 解析ISO8601日期
  static DateTime? parseIso8601(String? dateString) {
    if (dateString == null || dateString.isEmpty) return null;
    try {
      return DateTime.parse(dateString);
    } catch (e) {
      return null;
    }
  }

  /// 解析日期字符串
  static DateTime? parse(String? dateString,
      {String format = 'yyyy-MM-dd HH:mm:ss'}) {
    if (dateString == null || dateString.isEmpty) return null;
    try {
      return DateFormat(format).parse(dateString);
    } catch (e) {
      return null;
    }
  }

  // ==================== 工具方法 ====================
  /// 是否同一天
  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// 是否今天
  static bool isToday(DateTime date) => _isSameDay(date, DateTime.now());

  /// 是否昨天
  static bool isYesterday(DateTime date) =>
      _isSameDay(date, DateTime.now().subtract(const Duration(days: 1)));

  /// 是否本周
  static bool isThisWeek(DateTime date) {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    return date.isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
        date.isBefore(endOfWeek.add(const Duration(days: 1)));
  }

  /// 是否本月
  static bool isThisMonth(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month;
  }

  /// 是否本年
  static bool isThisYear(DateTime date) => date.year == DateTime.now().year;
}
