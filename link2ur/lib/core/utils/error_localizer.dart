import 'package:flutter/material.dart';
import '../utils/l10n_extension.dart';

/// 错误消息本地化工具
/// 将 API 返回的错误码转为本地化文字
class ErrorLocalizer {
  ErrorLocalizer._();

  /// 将错误消息转为本地化文本
  /// 如果是已知错误码，返回对应翻译；否则原样返回
  static String localize(BuildContext context, String? errorMessage) {
    if (errorMessage == null || errorMessage.isEmpty) {
      return context.l10n.errorUnknownGeneric;
    }

    switch (errorMessage) {
      case 'error_network_timeout':
        return context.l10n.errorNetworkTimeout;
      case 'error_request_failed':
        return context.l10n.errorRequestFailedGeneric;
      case 'error_request_cancelled':
        return context.l10n.errorRequestCancelled;
      case 'error_network_connection':
        return context.l10n.errorNetworkConnection;
      case 'error_unknown':
        return context.l10n.errorUnknownGeneric;
      default:
        // 服务端返回的已翻译消息，直接使用
        return errorMessage;
    }
  }
}
