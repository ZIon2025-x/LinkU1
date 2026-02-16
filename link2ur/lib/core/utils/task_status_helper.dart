import '../constants/app_constants.dart';
import '../../l10n/app_localizations.dart';

/// 任务状态国际化映射
class TaskStatusHelper {
  TaskStatusHelper._();

  /// 根据 status 获取国际化显示文案（随 locale 切换）
  static String getLocalizedLabel(String status, AppLocalizations l10n) {
    switch (status) {
      case AppConstants.taskStatusOpen:
        return l10n.taskStatusOpen;
      case AppConstants.taskStatusInProgress:
        return l10n.taskStatusInProgress;
      case AppConstants.taskStatusPendingConfirmation:
        return l10n.taskStatusPendingConfirmation;
      case AppConstants.taskStatusPendingPayment:
        return l10n.taskStatusPendingPayment;
      case AppConstants.taskStatusCompleted:
        return l10n.taskStatusCompleted;
      case AppConstants.taskStatusCancelled:
        return l10n.taskStatusCancelled;
      case AppConstants.taskStatusDisputed:
        return l10n.taskStatusDisputed;
      default:
        return status;
    }
  }
}
