import 'package:flutter/material.dart';

import 'responsive.dart';

/// Sheet iPad/平板适配工具 — 对齐 iOS SheetAdaptation
///
/// 在平板/桌面上约束 BottomSheet 最大宽度并居中，避免全宽拉伸。
/// iPhone 上保持原生全宽行为。
class SheetAdaptation {
  SheetAdaptation._();

  /// 平板/桌面上 Sheet 的最大宽度（对齐 iOS CustomerServiceView 600、部分 900）
  static const double tabletSheetMaxWidth = 600;

  /// 平板/桌面上大尺寸 Sheet 的最大宽度（表单、详情类）
  static const double tabletSheetMaxWidthLarge = 900;

  /// 为 Sheet 内容添加平板适配约束
  ///
  /// 平板及以上：居中 + 限制最大宽度
  /// 手机：不限制
  static Widget wrapWithTabletConstraints(
    BuildContext context, {
    required Widget child,
    double? maxWidth,
  }) {
    if (!ResponsiveUtils.isDesktop(context)) {
      return child;
    }
    final effectiveMaxWidth = maxWidth ?? tabletSheetMaxWidth;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
        child: child,
      ),
    );
  }

  /// 自适应展示 ModalBottomSheet
  ///
  /// 平板及以上：内容区限制最大宽度并居中
  /// 其他参数与 [showModalBottomSheet] 一致
  /// [showDragHandle] 为 false 时不显示顶部灰色拖拽条（弹窗仍可下拉关闭）
  static Future<T?> showAdaptiveModalBottomSheet<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool isScrollControlled = false,
    bool useRootNavigator = false,
    bool useSafeArea = false,
    Color? backgroundColor,
    double? elevation,
    ShapeBorder? shape,
    Clip? clipBehavior,
    Color? barrierColor,
    bool isDismissible = true,
    bool enableDrag = true,
    bool? showDragHandle,
    double? maxWidth,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      useRootNavigator: useRootNavigator,
      useSafeArea: useSafeArea,
      backgroundColor: backgroundColor,
      elevation: elevation,
      shape: shape,
      clipBehavior: clipBehavior,
      barrierColor: barrierColor,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      showDragHandle: showDragHandle,
      builder: (context) => wrapWithTabletConstraints(
        context,
        maxWidth: maxWidth,
        child: builder(context),
      ),
    );
  }

  /// 自适应展示 Dialog
  ///
  /// 平板及以上：内容区限制最大宽度并居中（对齐 iOS）
  /// 其他参数与 [showDialog] 一致
  static Future<T?> showAdaptiveDialog<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool barrierDismissible = true,
    String? barrierLabel,
    bool useSafeArea = true,
    RouteSettings? routeSettings,
    double? maxWidth,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: barrierLabel,
      useSafeArea: useSafeArea,
      routeSettings: routeSettings,
      builder: (context) => ResponsiveUtils.isDesktop(context)
          ? Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: maxWidth ?? tabletSheetMaxWidth,
                ),
                child: builder(context),
              ),
            )
          : builder(context),
    );
  }
}
