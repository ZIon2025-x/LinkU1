/// 应用异常基类
/// 所有仓库异常都继承此类，便于统一错误处理
class AppException implements Exception {
  const AppException(this.message, {this.code});

  /// 错误信息
  final String message;

  /// 错误码（可选）
  final String? code;

  @override
  String toString() => '${runtimeType.toString()}: $message';
}
