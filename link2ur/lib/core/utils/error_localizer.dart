import 'package:flutter/material.dart';
import '../utils/l10n_extension.dart';

/// BuildContext 便捷扩展，可直接在 Widget 内调用 `context.localizeError(msg)`
extension ErrorLocalizerExtension on BuildContext {
  String localizeError(String? errorMessage) =>
      ErrorLocalizer.localize(this, errorMessage);
}

/// 错误消息本地化工具
/// 将 API 返回的错误码转为本地化文字
class ErrorLocalizer {
  ErrorLocalizer._();

  /// 从异常对象提取用户可读的本地化消息
  /// 处理 DioException、SocketException 等常见网络/请求异常
  static String localizeFromException(BuildContext context, Object? error) {
    if (error == null) return context.l10n.errorUnknownGeneric;
    final msg = error.toString();
    if (msg.isEmpty) return context.l10n.errorUnknownGeneric;
    // 网络超时
    if (msg.contains('connection timeout') ||
        msg.contains('Connection timeout') ||
        msg.contains('TimeoutException')) {
      return context.l10n.errorNetworkTimeout;
    }
    // 网络连接失败
    if (msg.contains('connection refused') ||
        msg.contains('SocketException') ||
        msg.contains('connection reset')) {
      return context.l10n.errorNetworkConnection;
    }
    // 请求取消
    if (msg.contains('cancel')) return context.l10n.errorRequestCancelled;
    // 否则走通用本地化
    return localize(context, msg);
  }

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
      case 'auth_error_login_failed':
        return context.l10n.errorLoginFailed;
      case 'auth_error_register_failed':
        return context.l10n.errorRegisterFailed;
      case 'auth_error_send_code_failed':
        return context.l10n.errorCodeSendCodeFailed;
      case 'auth_reset_password_success':
        return context.l10n.successOperationSuccess;
      case 'auth_reset_password_failed':
        return context.l10n.feedbackOperationFailed;
      case 'search_error_failed':
        return context.l10n.errorRequestFailedGeneric;
      case 'flea_market_error_invalid_item_id':
        return context.l10n.errorInvalidInput;
      case 'customer_service_no_available_agent':
        return context.l10n.errorSomethingWentWrong;
      case 'ai_chat_load_conversations_failed':
        return context.l10n.aiChatLoadConversationsFailed;
      case 'ai_chat_create_conversation_failed':
        return context.l10n.aiChatCreateConversationFailed;
      case 'ai_chat_load_history_failed':
        return context.l10n.aiChatLoadHistoryFailed;
      case 'ai_chat_create_conversation_retry':
        return context.l10n.aiChatCreateConversationRetry;
      case 'unknown_error':
        return context.l10n.commonUnknownError;
      default:
        // 服务端返回的已翻译消息，直接使用
        return errorMessage;
    }
  }
}
