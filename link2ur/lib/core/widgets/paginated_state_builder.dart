import 'package:flutter/material.dart';

import 'empty_state_view.dart';
import 'error_state_view.dart';
import 'skeleton_view.dart';

/// 通用分页列表状态构建器
/// 统一处理 loading/error/empty/loaded 四种状态，减少各 View 中的重复代码
///
/// 用法示例：
/// ```dart
/// PaginatedStateBuilder(
///   isLoading: state.isLoading,
///   isEmpty: state.items.isEmpty,
///   hasError: state.hasError,
///   errorMessage: state.errorMessage,
///   onRetry: () => context.read<MyBloc>().add(LoadRequested()),
///   skeletonBuilder: () => const SkeletonGrid(...),
///   emptyBuilder: () => EmptyStateView.noData(context),
///   contentBuilder: () => ListView.builder(...),
/// )
/// ```
class PaginatedStateBuilder extends StatelessWidget {
  const PaginatedStateBuilder({
    super.key,
    required this.isLoading,
    required this.isEmpty,
    required this.hasError,
    this.errorMessage,
    this.onRetry,
    this.skeletonBuilder,
    this.emptyBuilder,
    required this.contentBuilder,
    this.emptyIcon,
    this.emptyTitle,
    this.emptyDescription,
  });

  /// 是否正在加载
  final bool isLoading;

  /// 数据是否为空
  final bool isEmpty;

  /// 是否有错误
  final bool hasError;

  /// 错误信息
  final String? errorMessage;

  /// 重试回调
  final VoidCallback? onRetry;

  /// 自定义骨架屏构建器（不提供则使用默认 SkeletonList）
  final Widget Function()? skeletonBuilder;

  /// 自定义空状态构建器
  final Widget Function()? emptyBuilder;

  /// 内容构建器（数据加载成功后显示）
  final Widget Function() contentBuilder;

  /// 空状态图标
  final IconData? emptyIcon;

  /// 空状态标题
  final String? emptyTitle;

  /// 空状态描述
  final String? emptyDescription;

  @override
  Widget build(BuildContext context) {
    // 加载中且无数据 → 骨架屏
    if (isLoading && isEmpty) {
      return skeletonBuilder?.call() ?? const SkeletonList();
    }

    // 错误且无数据 → 错误视图
    if (hasError && isEmpty) {
      return ErrorStateView(
        message: errorMessage ?? '加载失败',
        onRetry: onRetry,
      );
    }

    // 无数据 → 空状态
    if (isEmpty) {
      return emptyBuilder?.call() ??
          EmptyStateView(
            icon: emptyIcon ?? Icons.inbox_outlined,
            title: emptyTitle ?? '暂无数据',
            message: emptyDescription,
          );
    }

    // 有数据 → 显示内容
    return contentBuilder();
  }
}
