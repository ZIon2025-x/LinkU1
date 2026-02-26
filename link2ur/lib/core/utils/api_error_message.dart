import '../../l10n/app_localizations.dart';
import '../../data/services/api_service.dart';

/// 根据 [ApiResponse] 的 [errorCode] 与 [message] 返回用于展示的本地化错误文案。
/// 当 [response.errorCode] 存在且能在 l10n 中找到对应文案时优先使用本地化字符串，
/// 否则回退到 [response.message]（后端返回的 message 或客户端 fallback）。
String getApiDisplayMessage(ApiResponse<dynamic> response, AppLocalizations l10n) {
  final code = response.errorCode;
  if (code == null || code.isEmpty) {
    return response.message ?? '';
  }
  switch (code) {
    case 'EMAIL_ALREADY_USED':
      return l10n.errorCodeEmailAlreadyUsed;
    case 'EMAIL_ALREADY_EXISTS':
      return l10n.errorCodeEmailAlreadyExists;
    case 'PHONE_ALREADY_USED':
      return l10n.errorCodePhoneAlreadyUsed;
    case 'PHONE_ALREADY_EXISTS':
      return l10n.errorCodePhoneAlreadyExists;
    case 'USERNAME_ALREADY_EXISTS':
      return l10n.errorCodeUsernameAlreadyExists;
    case 'CODE_INVALID_OR_EXPIRED':
      return l10n.errorCodeCodeInvalidOrExpired;
    case 'SEND_CODE_FAILED':
      return l10n.errorCodeSendCodeFailed;
    case 'EMAIL_UPDATE_NEED_CODE':
      return l10n.errorCodeEmailUpdateNeedCode;
    case 'PHONE_UPDATE_NEED_CODE':
      return l10n.errorCodePhoneUpdateNeedCode;
    case 'TEMP_EMAIL_NOT_ALLOWED':
      return l10n.errorCodeTempEmailNotAllowed;
    case 'LOGIN_REQUIRED':
      return l10n.errorCodeLoginRequired;
    case 'FORBIDDEN_VIEW':
      return l10n.errorCodeForbiddenView;
    case 'TASK_ALREADY_APPLIED':
      return l10n.errorCodeTaskAlreadyApplied;
    case 'DISPUTE_ALREADY_SUBMITTED':
      return l10n.errorCodeDisputeAlreadySubmitted;
    case 'REBUTTAL_ALREADY_SUBMITTED':
      return l10n.errorCodeRebuttalAlreadySubmitted;
    case 'TASK_NOT_PAID':
      return l10n.errorCodeTaskNotPaid;
    case 'TASK_PAYMENT_UNAVAILABLE':
      return l10n.errorCodeTaskPaymentUnavailable;
    case 'STRIPE_DISPUTE_FROZEN':
      return l10n.errorCodeStripeDisputeFrozen;
    case 'STRIPE_SETUP_REQUIRED':
      return l10n.errorCodeStripeSetupRequired;
    case 'STRIPE_OTHER_PARTY_NOT_SETUP':
      return l10n.errorCodeStripeOtherPartyNotSetup;
    case 'STRIPE_ACCOUNT_NOT_VERIFIED':
      return l10n.errorCodeStripeAccountNotVerified;
    case 'STRIPE_ACCOUNT_INVALID':
      return l10n.errorCodeStripeAccountInvalid;
    case 'STRIPE_VERIFICATION_FAILED':
      return l10n.errorCodeStripeVerificationFailed;
    case 'REFUND_AMOUNT_REQUIRED':
      return l10n.errorCodeRefundAmountRequired;
    case 'EVIDENCE_FILES_LIMIT':
      return l10n.errorCodeEvidenceFilesLimit;
    case 'EVIDENCE_TEXT_LIMIT':
      return l10n.errorCodeEvidenceTextLimit;
    case 'ACCOUNT_HAS_ACTIVE_TASKS':
      return l10n.errorCodeAccountHasActiveTasks;
    case 'TEMP_EMAIL_NO_PASSWORD_RESET':
      return l10n.errorCodeTempEmailNoPasswordReset;
    default:
      return response.message ?? '';
  }
}
