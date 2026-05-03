import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

/// 让 Bloc 事件能够把"处理完成"的信号回传给视图层。
///
/// 之所以用 Completer 而不是 `bloc.stream.firstWhere(!isLoading)`：
/// - handler 抛异常或 catch 块漏 emit 时，stream 不会发射，下拉刷新指示器会
///   永远不停止；
/// - 不同 Bloc 用 `isLoading` / `isRefreshing` / `status != loading` 表示忙碌，
///   视图层不该关心字段名。
///
/// **handler 必须在 `finally` 里调用 `event.refreshCompleter?.complete()`**
/// （即使 `try` 抛异常，`finally` 也会执行；catch 仍要 emit errorMessage 让 UI
/// 显示失败反馈）。
mixin RefreshSignal {
  Completer<void>? get refreshCompleter;
}

/// 触发一个带 [RefreshSignal] 的事件，并等待 handler 完成。
///
/// [timeout] 是兜底；handler 不可达（比如被 droppable 丢弃）或 finally 没运行
/// 时，timeout 到点 future 也会 resolve，下拉指示器不会卡死。
///
/// 用法：
/// ```dart
/// onRefresh: () => awaitRefresh(
///   context.read<TaskExpertBloc>(),
///   (c) => TaskExpertRefreshRequested(refreshCompleter: c),
/// ),
/// ```
Future<void> awaitRefresh<E extends RefreshSignal>(
  Bloc bloc,
  E Function(Completer<void> completer) buildEvent, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final completer = Completer<void>();
  bloc.add(buildEvent(completer));
  try {
    await completer.future.timeout(timeout);
  } on TimeoutException {
    // 兜底超时：让指示器停下，UI 保持当前状态
  }
}
