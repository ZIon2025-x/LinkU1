import 'dart:ui' show Locale;

/// 根据 locale 选择中文/英文显示
///
/// - zh 系语言：优先 zh → en → fallback
/// - 其他语言：优先 en → zh → fallback
String localizedString(
  String? zh,
  String? en,
  String fallback,
  Locale locale,
) {
  final preferZh = locale.languageCode.startsWith('zh');
  if (preferZh) {
    return zh ?? en ?? fallback;
  } else {
    return en ?? zh ?? fallback;
  }
}

/// 可选字符串版本，返回 null 当所有为空
String? localizedStringOrNull(String? zh, String? en, String? fallback, Locale locale) {
  final preferZh = locale.languageCode.startsWith('zh');
  if (preferZh) {
    return zh ?? en ?? fallback;
  } else {
    return en ?? zh ?? fallback;
  }
}

/// 列表版本（如 specialties、achievements）
List<String> localizedList(
  List<String>? zh,
  List<String>? en,
  List<String>? fallback,
  Locale locale,
) {
  final preferZh = locale.languageCode.startsWith('zh');
  if (preferZh) {
    return zh ?? en ?? fallback ?? [];
  } else {
    return en ?? zh ?? fallback ?? [];
  }
}
