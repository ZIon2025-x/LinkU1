import 'package:flutter/services.dart';

import '../config/app_config.dart';
import 'haptic_feedback.dart';

/// 通用工具方法
class Helpers {
  Helpers._();

  // ==================== 货币格式化 ====================
  /// 货币符号（统一英镑）
  static const String currencySymbol = '£';

  /// 格式化价格（统一英镑）：整数不显示小数，否则保留两位
  static String formatPrice(double price, {String currency = 'GBP'}) {
    return '$currencySymbol${formatAmountNumber(price)}';
  }

  /// 仅格式化金额数字部分：整数返回无小数（如 "12"），否则两位小数（如 "12.34"）
  /// 用于 UI 中单独显示货币符号 + 数字，或输入框预填
  static String formatAmountNumber(num amount) {
    final d = amount.toDouble();
    if (d == d.truncateToDouble()) return d.toInt().toString();
    return d.toStringAsFixed(2);
  }

  // ==================== 数字格式化 ====================
  /// 格式化数量（1000 -> 1K）
  static String formatCount(int count) {
    if (count < 1000) {
      return count.toString();
    } else if (count < 10000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    } else if (count < 1000000) {
      return '${(count / 1000).toInt()}K';
    } else {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    }
  }

  /// 格式化距离
  static String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toInt()}m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)}km';
    }
  }

  /// 格式化文件大小
  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '${bytes}B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)}KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
    }
  }

  // ==================== 字符串处理 ====================
  /// 隐藏手机号中间4位
  static String maskPhone(String phone) {
    if (phone.length < 7) return phone;
    return '${phone.substring(0, 3)}****${phone.substring(phone.length - 4)}';
  }

  /// 隐藏邮箱
  static String maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 2) {
      return '$name***@$domain';
    }
    return '${name.substring(0, 2)}***@$domain';
  }

  /// 截断文本
  static String truncate(String text, int maxLength, {String suffix = '...'}) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}$suffix';
  }

  /// 将帖子/回复内容中的标记转为真实换行和空格（与 iOS ContentFormatter 一致）。
  /// 标记规则：\n → 换行，\c → 空格，\r\n / \r → 换行。
  static String normalizeContentNewlines(String text) {
    if (text.isEmpty) return text;
    return text
        .replaceAll(r'\r\n', '\n')
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\r', '\n')
        .replaceAll(r'\c', ' ');
  }

  // ==================== 颜色处理 ====================
  /// 从十六进制字符串创建颜色
  static Color hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    return Color(int.parse(hex, radix: 16));
  }

  /// 颜色转十六进制字符串
  static String colorToHex(Color color, {bool includeAlpha = false}) {
    if (includeAlpha) {
      return '#${color.toARGB32().toRadixString(16).padLeft(8, '0')}';
    }
    return '#${color.toARGB32().toRadixString(16).substring(2).padLeft(6, '0')}';
  }

  // ==================== 触觉反馈（委托到 AppHaptics 统一管理） ====================
  /// 轻触反馈
  static void hapticLight() => AppHaptics.light();

  /// 中等反馈
  static void hapticMedium() => AppHaptics.medium();

  /// 重触反馈
  static void hapticHeavy() => AppHaptics.heavy();

  /// 选择反馈
  static void hapticSelection() => AppHaptics.selection();

  /// 成功反馈
  static void hapticSuccess() => AppHaptics.success();

  /// 错误反馈
  static void hapticError() => AppHaptics.error();

  // ==================== 复制到剪贴板 ====================
  static Future<void> copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    hapticLight();
  }

  // ==================== URL处理 ====================
  /// 获取图片完整 URL。
  /// 需在 CDN（如 Cloudflare）上为 app.link2ur.com 配置 CORS，否则 Web 端跨域加载会失败。见 link2ur/docs/cdn-cors-setup.md。
  static String getImageUrl(String? path, {String? baseUrl}) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    final base = baseUrl ?? AppConfig.instance.baseUrl;
    return '$base$path';
  }

  /// 获取文件/资源完整 URL（下载、PDF 等）。
  /// 同样依赖 CDN 对 app.link2ur.com 的 CORS 配置。
  static String getResourceUrl(String? path, {String? baseUrl}) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    final base = baseUrl ?? AppConfig.instance.baseUrl;
    return '$base$path';
  }

  // ==================== 列表处理 ====================
  /// 安全获取列表元素
  static T? safeGet<T>(List<T>? list, int index) {
    if (list == null || index < 0 || index >= list.length) return null;
    return list[index];
  }

  /// 列表分组
  static Map<K, List<T>> groupBy<T, K>(List<T> list, K Function(T) keySelector) {
    final map = <K, List<T>>{};
    for (final item in list) {
      final key = keySelector(item);
      map.putIfAbsent(key, () => []).add(item);
    }
    return map;
  }
}

/// 扩展方法
extension StringExtension on String {
  /// 首字母大写
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  /// 是否为空白
  bool get isBlank => trim().isEmpty;

  /// 是否不为空白
  bool get isNotBlank => !isBlank;
}

extension ListExtension<T> on List<T> {
  /// 安全获取元素
  T? getOrNull(int index) {
    if (index < 0 || index >= length) return null;
    return this[index];
  }
}
