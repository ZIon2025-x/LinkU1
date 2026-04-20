import 'dart:ui' show Locale;

/// 根据 locale 选择中文/英文显示
///
/// fallback 通常是后端"原文"字段（如 bio），是作者自己填写的，
/// 可能是中文也可能是英文 — 优先级应高于"另一语言的翻译"。
///
/// - zh 系语言：zh → fallback → en
/// - 其他语言：en → fallback → zh
String localizedString(
  String? zh,
  String? en,
  String fallback,
  Locale locale,
) {
  final preferZh = locale.languageCode.startsWith('zh');
  if (preferZh) {
    return _firstNonEmpty(zh, fallback, en) ?? fallback;
  } else {
    return _firstNonEmpty(en, fallback, zh) ?? fallback;
  }
}

/// 可选字符串版本，返回 null 当所有为空
String? localizedStringOrNull(String? zh, String? en, String? fallback, Locale locale) {
  final preferZh = locale.languageCode.startsWith('zh');
  if (preferZh) {
    return _firstNonEmpty(zh, fallback, en);
  } else {
    return _firstNonEmpty(en, fallback, zh);
  }
}

String? _firstNonEmpty(String? a, String? b, String? c) {
  if (a != null && a.isNotEmpty) return a;
  if (b != null && b.isNotEmpty) return b;
  if (c != null && c.isNotEmpty) return c;
  return null;
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
    return _firstNonEmptyList(zh, fallback, en) ?? [];
  } else {
    return _firstNonEmptyList(en, fallback, zh) ?? [];
  }
}

List<String>? _firstNonEmptyList(List<String>? a, List<String>? b, List<String>? c) {
  if (a != null && a.isNotEmpty) return a;
  if (b != null && b.isNotEmpty) return b;
  if (c != null && c.isNotEmpty) return c;
  return null;
}
