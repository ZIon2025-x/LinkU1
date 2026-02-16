import '../constants/app_constants.dart';
import '../../l10n/app_localizations.dart';

/// 学生认证状态国际化映射
class VerificationStatusHelper {
  VerificationStatusHelper._();

  static String getLocalizedLabel(String? status, AppLocalizations l10n) {
    switch (status) {
      case AppConstants.verificationStatusPending:
        return l10n.studentVerificationStatusPending;
      case 'verified':
        return l10n.studentVerificationVerified;
      case AppConstants.verificationStatusExpired:
        return l10n.studentVerificationStatusExpired;
      case AppConstants.verificationStatusRevoked:
        return l10n.studentVerificationStatusRevoked;
      default:
        return l10n.studentVerificationUnverified;
    }
  }
}
