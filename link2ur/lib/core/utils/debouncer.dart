import 'dart:async';

/// 防抖工具类
/// 在指定延迟内多次调用只执行最后一次，适用于搜索输入、滚动事件等场景
class Debouncer {
  Debouncer({this.duration = const Duration(milliseconds: 400)});

  final Duration duration;
  Timer? _timer;

  /// 执行防抖回调
  /// 如果在 [duration] 内再次调用，前一次回调会被取消
  void call(void Function() callback) {
    _timer?.cancel();
    _timer = Timer(duration, callback);
  }

  /// 取消待执行的回调
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  /// 是否有待执行的回调
  bool get isActive => _timer?.isActive ?? false;

  /// 释放资源（在 dispose 中调用）
  void dispose() {
    cancel();
  }
}
