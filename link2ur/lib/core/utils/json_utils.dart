/// JSON 解析工具函数
///
/// 后端返回的布尔字段可能是 bool、int(0/1) 或 String("true"/"1")，
/// 统一用这些方法安全解析，避免 type cast 异常。

/// 解析布尔值，默认 false
bool parseBool(dynamic value, [bool defaultValue = false]) {
  if (value == null) return defaultValue;
  if (value is bool) return value;
  if (value is int) return value != 0;
  if (value is String) return value == 'true' || value == '1';
  return defaultValue;
}

/// 解析可空布尔值
bool? parseBoolNullable(dynamic value) {
  if (value == null) return null;
  if (value is bool) return value;
  if (value is int) return value != 0;
  if (value is String) return value == 'true' || value == '1';
  return null;
}
