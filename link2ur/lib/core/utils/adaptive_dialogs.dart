import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'sheet_adaptation.dart';

/// 平台自适应弹窗工具
///
/// iOS 使用 Cupertino 风格（CupertinoAlertDialog / CupertinoActionSheet），
/// Android / Web / Desktop 使用 Material 风格并通过 [SheetAdaptation] 保持平板约束。
class AdaptiveDialogs {
  AdaptiveDialogs._();

  /// 是否为 iOS 平台（Web 上始终返回 false，避免 dart:io 崩溃）
  static bool get _isIOS => !kIsWeb && Platform.isIOS;

  // ---------------------------------------------------------------------------
  // 1. Confirm Dialog — 确认 / 取消
  // ---------------------------------------------------------------------------

  /// 显示确认弹窗，返回用户选择结果。
  ///
  /// - iOS: [CupertinoAlertDialog] + [CupertinoDialogAction]
  /// - Android: [AlertDialog] via [SheetAdaptation.showAdaptiveDialog]
  ///
  /// [content] 和 [contentWidget] 二选一；都传时优先 [contentWidget]。
  /// [isDestructive] 为 true 时确认按钮显示为红色/破坏性样式。
  /// [onConfirm] / [onCancel] 仅在用户点击对应按钮后调用，弹窗会自动关闭。
  static Future<T?> showConfirmDialog<T>({
    required BuildContext context,
    required String title,
    String? content,
    Widget? contentWidget,
    String confirmText = '确定',
    String cancelText = '取消',
    bool isDestructive = false,
    bool barrierDismissible = true,
    T Function()? onConfirm,
    T Function()? onCancel,
  }) {
    if (_isIOS) {
      return showCupertinoDialog<T>(
        context: context,
        barrierDismissible: barrierDismissible,
        builder: (ctx) => CupertinoAlertDialog(
          title: Text(title),
          content: contentWidget ??
              (content != null ? Text(content) : null),
          actions: [
            CupertinoDialogAction(
              onPressed: () {
                final result = onCancel?.call();
                Navigator.of(ctx).pop(result);
              },
              child: Text(cancelText),
            ),
            CupertinoDialogAction(
              isDestructiveAction: isDestructive,
              isDefaultAction: !isDestructive,
              onPressed: () {
                final result = onConfirm?.call();
                Navigator.of(ctx).pop(result ?? true as T);
              },
              child: Text(confirmText),
            ),
          ],
        ),
      );
    }

    // Android / Web / Desktop — Material
    return SheetAdaptation.showAdaptiveDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          title: Text(title),
          content: contentWidget ??
              (content != null ? Text(content) : null),
          actions: [
            TextButton(
              onPressed: () {
                final result = onCancel?.call();
                Navigator.of(ctx).pop(result);
              },
              child: Text(cancelText),
            ),
            if (isDestructive)
              TextButton(
                onPressed: () {
                  final result = onConfirm?.call();
                  Navigator.of(ctx).pop(result ?? true as T);
                },
                child: Text(
                  confirmText,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              )
            else
              FilledButton(
                onPressed: () {
                  final result = onConfirm?.call();
                  Navigator.of(ctx).pop(result ?? true as T);
                },
                child: Text(confirmText),
              ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 2. Info Dialog — 单按钮信息弹窗
  // ---------------------------------------------------------------------------

  /// 显示信息弹窗，仅包含一个"好"按钮。
  ///
  /// - iOS: [CupertinoAlertDialog] + 单个 [CupertinoDialogAction]
  /// - Android: [AlertDialog] + [FilledButton]
  static Future<void> showInfoDialog({
    required BuildContext context,
    required String title,
    String? content,
    Widget? contentWidget,
    String okText = '好',
    bool barrierDismissible = true,
  }) {
    if (_isIOS) {
      return showCupertinoDialog<void>(
        context: context,
        barrierDismissible: barrierDismissible,
        builder: (ctx) => CupertinoAlertDialog(
          title: Text(title),
          content: contentWidget ??
              (content != null ? Text(content) : null),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(okText),
            ),
          ],
        ),
      );
    }

    return SheetAdaptation.showAdaptiveDialog<void>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: contentWidget ??
            (content != null ? Text(content) : null),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(okText),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Input Dialog — 带输入框的弹窗
  // ---------------------------------------------------------------------------

  /// 显示带文本输入框的弹窗，返回用户输入的字符串（取消返回 null）。
  ///
  /// - iOS: [CupertinoAlertDialog] + [CupertinoTextField]
  /// - Android: [AlertDialog] + [TextField]
  static Future<String?> showInputDialog({
    required BuildContext context,
    required String title,
    String? message,
    String? placeholder,
    String? initialValue,
    String confirmText = '确定',
    String cancelText = '取消',
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    if (_isIOS) {
      return _showCupertinoInputDialog(
        context: context,
        title: title,
        message: message,
        placeholder: placeholder,
        initialValue: initialValue,
        confirmText: confirmText,
        cancelText: cancelText,
        maxLines: maxLines,
        keyboardType: keyboardType,
      );
    }

    return _showMaterialInputDialog(
      context: context,
      title: title,
      message: message,
      placeholder: placeholder,
      initialValue: initialValue,
      confirmText: confirmText,
      cancelText: cancelText,
      maxLines: maxLines,
      keyboardType: keyboardType,
    );
  }

  static Future<String?> _showCupertinoInputDialog({
    required BuildContext context,
    required String title,
    String? message,
    String? placeholder,
    String? initialValue,
    required String confirmText,
    required String cancelText,
    required int maxLines,
    TextInputType? keyboardType,
  }) {
    final controller = TextEditingController(text: initialValue);

    return showCupertinoDialog<String>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(message),
            ],
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: controller,
              placeholder: placeholder,
              maxLines: maxLines,
              keyboardType: keyboardType,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () {
              controller.dispose();
              Navigator.of(ctx).pop();
            },
            child: Text(cancelText),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              final value = controller.text;
              controller.dispose();
              Navigator.of(ctx).pop(value);
            },
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  static Future<String?> _showMaterialInputDialog({
    required BuildContext context,
    required String title,
    String? message,
    String? placeholder,
    String? initialValue,
    required String confirmText,
    required String cancelText,
    required int maxLines,
    TextInputType? keyboardType,
  }) {
    final controller = TextEditingController(text: initialValue);

    return SheetAdaptation.showAdaptiveDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message != null) ...[
              Text(message),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: placeholder,
                border: const OutlineInputBorder(),
              ),
              maxLines: maxLines,
              keyboardType: keyboardType,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              controller.dispose();
              Navigator.of(ctx).pop();
            },
            child: Text(cancelText),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text;
              controller.dispose();
              Navigator.of(ctx).pop(value);
            },
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. Action Sheet — 底部操作列表
  // ---------------------------------------------------------------------------

  /// 显示底部操作列表。
  ///
  /// - iOS: [CupertinoActionSheet] via [showCupertinoModalPopup]
  /// - Android: [showAdaptiveModalBottomSheet] 内包含 [ListTile] 列表
  ///
  /// 返回用户选择的 [AdaptiveAction.value]，取消/外部关闭返回 null。
  static Future<T?> showActionSheet<T>({
    required BuildContext context,
    String? title,
    String? message,
    required List<AdaptiveAction<T>> actions,
    String cancelText = '取消',
  }) {
    if (_isIOS) {
      return showCupertinoModalPopup<T>(
        context: context,
        builder: (ctx) => CupertinoActionSheet(
          title: title != null ? Text(title) : null,
          message: message != null ? Text(message) : null,
          actions: actions.map((action) {
            return CupertinoActionSheetAction(
              isDestructiveAction: action.isDestructive,
              isDefaultAction: action.isDefault,
              onPressed: () => Navigator.of(ctx).pop(action.value),
              child: Text(action.label),
            );
          }).toList(),
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(cancelText),
          ),
        ),
      );
    }

    // Android / Web / Desktop — Material BottomSheet
    return SheetAdaptation.showAdaptiveModalBottomSheet<T>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null || message != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (title != null)
                        Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      if (title != null && message != null)
                        const SizedBox(height: 4),
                      if (message != null)
                        Text(
                          message,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                    ],
                  ),
                ),
              if (title != null || message != null) const Divider(height: 1),
              ...actions.map((action) {
                final textColor = action.isDestructive
                    ? theme.colorScheme.error
                    : null;
                return ListTile(
                  leading: action.icon != null
                      ? Icon(action.icon, color: textColor)
                      : null,
                  title: Text(
                    action.label,
                    style: TextStyle(
                      color: textColor,
                      fontWeight:
                          action.isDefault ? FontWeight.w600 : null,
                    ),
                  ),
                  onTap: () => Navigator.of(ctx).pop(action.value),
                );
              }),
              const Divider(height: 1),
              ListTile(
                title: Text(
                  cancelText,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
                onTap: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        );
      },
    );
  }
}

// =============================================================================
// AdaptiveAction — Action Sheet 选项模型
// =============================================================================

/// [AdaptiveDialogs.showActionSheet] 的选项定义。
class AdaptiveAction<T> {
  const AdaptiveAction({
    required this.label,
    required this.value,
    this.icon,
    this.isDestructive = false,
    this.isDefault = false,
  });

  /// 显示文本
  final String label;

  /// 选中后返回的值
  final T value;

  /// 可选图标（仅 Material 风格的 ListTile 显示）
  final IconData? icon;

  /// 是否为破坏性操作（红色文字）
  final bool isDestructive;

  /// 是否为默认/推荐操作（iOS 加粗，Material 加粗）
  final bool isDefault;
}
