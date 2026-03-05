import 'package:flutter/material.dart';

/// iOS 16+ 原生右键菜单（含翻译、查找、分享等系统菜单项）
/// 不支持的平台自动回退到 Flutter 默认菜单
Widget systemContextMenuBuilder(
  BuildContext context,
  EditableTextState editableTextState,
) {
  if (SystemContextMenu.isSupported(context)) {
    return SystemContextMenu.editableText(
      editableTextState: editableTextState,
    );
  }
  return AdaptiveTextSelectionToolbar.editableText(
    editableTextState: editableTextState,
  );
}
