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

    // Strip exception class prefix (e.g. "FleaMarketException: msg" → "msg")
    final colonIdx = errorMessage.indexOf(': ');
    final code = (colonIdx > 0 && colonIdx < 40)
        ? errorMessage.substring(colonIdx + 2)
        : errorMessage;

    switch (code) {
      case 'public_reply_failed':
        return context.l10n.actionOperationFailed;
      case 'public_reply_already_replied':
        return context.l10n.alreadyReplied;
      case 'qa_ask_failed':
      case 'qa_reply_failed':
      case 'qa_delete_failed':
        return context.l10n.actionOperationFailed;
      case 'qa_cannot_ask_own':
        return context.l10n.qaCannotAskOwn;
      case 'qa_already_replied':
        return context.l10n.qaAlreadyReplied;
      case 'qa_content_too_short':
        return context.l10n.qaContentTooShort;
      case 'qa_no_permission':
        return context.l10n.qaNoPermission;
      case 'qa_not_found':
        return context.l10n.qaNotFound;
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
      case 'email_required':
        return context.l10n.errorEmailRequired;
      case 'email_already_registered':
        return context.l10n.errorEmailAlreadyRegistered;
      case 'username_already_taken':
        return context.l10n.errorUsernameAlreadyTaken;
      case 'username_contains_reserved_keywords':
        return context.l10n.errorUsernameReservedKeywords;
      case 'terms_not_agreed':
        return context.l10n.errorTermsNotAgreed;
      case 'password_too_weak':
        return context.l10n.errorPasswordTooWeak;
      case 'verification_code_invalid':
        return context.l10n.errorVerificationCodeInvalid;
      case 'auth_error_send_code_failed':
        return context.l10n.errorCodeSendCodeFailed;
      case 'auth_reset_password_success':
        return context.l10n.successOperationSuccess;
      case 'auth_reset_password_failed':
        return context.l10n.feedbackOperationFailed;
      case 'search_error_failed':
        return context.l10n.errorRequestFailedGeneric;
      case 'flea_market_error_invalid_item_id':
        return context.l10n.fleaMarketErrorInvalidItemId;
      case 'flea_market_item_deleted':
        return context.l10n.fleaMarketItemDeleted;
      case 'flea_market_item_not_found':
        return context.l10n.fleaMarketItemNotFound;
      case 'flea_market_error_get_list_failed':
        return context.l10n.fleaMarketErrorGetListFailed;
      case 'flea_market_error_get_categories_failed':
        return context.l10n.fleaMarketErrorGetCategoriesFailed;
      case 'flea_market_error_get_detail_failed':
        return context.l10n.fleaMarketErrorGetDetailFailed;
      case 'flea_market_error_publish_failed':
        return context.l10n.fleaMarketErrorPublishFailed;
      case 'flea_market_error_purchase_failed':
        return context.l10n.fleaMarketErrorPurchaseFailed;
      case 'flea_market_error_send_purchase_request_failed':
        return context.l10n.fleaMarketErrorSendPurchaseRequestFailed;
      case 'flea_market_error_operation_failed':
        return context.l10n.fleaMarketErrorOperationFailed;
      case 'flea_market_error_refresh_failed':
        return context.l10n.fleaMarketErrorRefreshFailed;
      case 'flea_market_error_report_failed':
        return context.l10n.fleaMarketErrorReportFailed;
      case 'flea_market_error_get_my_related_failed':
        return context.l10n.fleaMarketErrorGetMyRelatedFailed;
      case 'flea_market_error_get_purchase_history_failed':
        return context.l10n.fleaMarketErrorGetPurchaseHistoryFailed;
      case 'flea_market_error_get_favorites_failed':
        return context.l10n.fleaMarketErrorGetFavoritesFailed;
      case 'flea_market_error_user_not_logged_in':
        return context.l10n.fleaMarketErrorUserNotLoggedIn;
      case 'flea_market_error_get_my_items_failed':
        return context.l10n.fleaMarketErrorGetMyItemsFailed;
      case 'flea_market_error_get_sales_failed':
        return context.l10n.fleaMarketErrorGetSalesFailed;
      case 'flea_market_error_approve_failed':
        return context.l10n.fleaMarketErrorApproveFailed;
      case 'flea_market_error_upload_image_failed':
        return context.l10n.fleaMarketErrorUploadImageFailed;
      case 'flea_market_error_update_failed':
        return context.l10n.fleaMarketErrorUpdateFailed;
      case 'flea_market_error_delete_failed':
        return context.l10n.fleaMarketErrorDeleteFailed;
      case 'flea_market_error_get_purchase_requests_failed':
        return context.l10n.fleaMarketErrorGetPurchaseRequestsFailed;
      case 'flea_market_error_accept_failed':
        return context.l10n.fleaMarketErrorAcceptFailed;
      case 'flea_market_error_reject_failed':
        return context.l10n.fleaMarketErrorRejectFailed;
      case 'flea_market_error_counter_offer_failed':
        return context.l10n.fleaMarketErrorCounterOfferFailed;
      case 'flea_market_error_respond_counter_offer_failed':
        return context.l10n.fleaMarketErrorRespondCounterOfferFailed;
      case 'refund_not_found':
        return context.l10n.refundNotFound;
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
      case 'ai_chat_response_timeout':
        return context.l10n.aiChatResponseTimeout;
      case 'chat_load_failed':
        return context.l10n.chatLoadFailed;
      case 'chat_load_more_failed':
        return context.l10n.chatLoadMoreFailed;
      case 'chat_network_offline':
        return context.l10n.chatNetworkOffline;
      case 'chat_send_message_failed':
        return context.l10n.chatSendMessageFailed;
      case 'chat_send_image_failed':
        return context.l10n.chatSendImageFailed;
      case 'task_refund_amount_invalid':
        return context.l10n.taskRefundAmountInvalid;
      case 'task_negotiation_invalid_action':
        return context.l10n.taskNegotiationInvalidAction;
      case 'unknown_error':
        return context.l10n.commonUnknownError;
      case 'submit_failed':
        return context.l10n.leaderboardSubmitFailed;
      case 'vote_failed':
        return context.l10n.leaderboardVoteFailed;
      case 'wallet_load_failed':
        return context.l10n.errorRequestFailedGeneric;
      case 'wallet_load_more_failed':
        return context.l10n.errorRequestFailedGeneric;
      case 'coupon_points_load_transactions_failed':
        return context.l10n.errorCouponPointsLoadTransactionsFailed;
      case 'coupon_points_load_more_transactions_failed':
        return context.l10n.errorCouponPointsLoadMoreTransactionsFailed;
      case 'error_invalid_payment_amount':
        return context.l10n.errorInvalidPaymentAmount;
      case 'verification_email_not_found':
        return context.l10n.errorVerificationEmailNotFound;
      case 'create_task_failed':
        return context.l10n.errorCreateTaskFailed;
      case 'task_application_id_not_found':
        return context.l10n.errorTaskApplicationIdNotFound;
      case 'task_detail_load_failed':
        return context.l10n.errorTaskDetailLoadFailed;
      case 'task_applications_load_failed':
        return context.l10n.errorTaskApplicationsLoadFailed;
      case 'task_reviews_load_failed':
        return context.l10n.errorTaskReviewsLoadFailed;
      case 'task_apply_failed':
        return context.l10n.errorTaskApplyFailed;
      case 'task_cancel_application_failed':
        return context.l10n.errorTaskCancelApplicationFailed;
      case 'task_accept_applicant_failed':
        return context.l10n.errorTaskAcceptApplicantFailed;
      case 'task_reject_applicant_failed':
        return context.l10n.errorTaskRejectApplicantFailed;
      case 'task_complete_failed':
        return context.l10n.errorTaskCompleteFailed;
      case 'task_confirm_completion_failed':
        return context.l10n.errorTaskConfirmCompletionFailed;
      case 'task_cancel_failed':
        return context.l10n.errorTaskCancelFailed;
      case 'task_review_failed':
        return context.l10n.errorTaskReviewFailed;
      case 'task_refund_request_failed':
        return context.l10n.errorTaskRefundRequestFailed;
      case 'task_refund_history_load_failed':
        return context.l10n.errorTaskRefundHistoryLoadFailed;
      case 'task_cancel_refund_failed':
        return context.l10n.errorTaskCancelRefundFailed;
      case 'task_rebuttal_failed':
        return context.l10n.errorTaskRebuttalFailed;
      case 'task_send_message_failed':
        return context.l10n.errorTaskSendMessageFailed;
      case 'task_counter_offer_failed':
        return context.l10n.errorTaskCounterOfferFailed;
      case 'task_respond_counter_offer_failed':
        return context.l10n.errorTaskRespondCounterOfferFailed;
      case 'task_respond_negotiation_failed':
        return context.l10n.errorTaskRespondNegotiationFailed;
      case 'task_visibility_update_failed':
        return context.l10n.errorTaskVisibilityUpdateFailed;
      case 'task_start_chat_failed':
        return context.l10n.errorTaskStartChatFailed;
      case 'task_propose_price_failed':
        return context.l10n.errorTaskProposePriceFailed;
      case 'task_confirm_pay_failed':
        return context.l10n.errorTaskConfirmPayFailed;
      case 'task_list_load_failed':
        return context.l10n.errorTaskListLoadFailed;
      case 'task_quote_failed':
        return context.l10n.errorTaskQuoteFailed;
      case 'task_quote_accept_failed':
        return context.l10n.errorTaskQuoteAcceptFailed;
      case 'forum_create_post_failed':
        return context.l10n.errorForumCreatePostFailed;
      case 'activity_load_failed':
        return context.l10n.errorActivityLoadFailed;
      case 'activity_load_more_failed':
        return context.l10n.errorActivityLoadMoreFailed;
      case 'activity_refresh_failed':
        return context.l10n.errorActivityRefreshFailed;
      case 'activity_apply_failed':
        return context.l10n.errorActivityApplyFailed;
      case 'activity_detail_load_failed':
        return context.l10n.errorActivityDetailLoadFailed;
      case 'activity_toggle_favorite_failed':
        return context.l10n.errorActivityToggleFavoriteFailed;
      case 'profile_load_failed':
        return context.l10n.errorProfileLoadFailed;
      case 'profile_update_failed':
        return context.l10n.errorProfileUpdateFailed;
      case 'profile_update_avatar_failed':
        return context.l10n.errorProfileUpdateAvatarFailed;
      case 'profile_upload_avatar_failed':
        return context.l10n.errorProfileUploadAvatarFailed;
      case 'profile_load_tasks_failed':
        return context.l10n.errorProfileLoadTasksFailed;
      case 'profile_load_public_failed':
        return context.l10n.errorProfileLoadPublicFailed;
      case 'profile_load_forum_posts_failed':
        return context.l10n.errorProfileLoadForumPostsFailed;
      case 'profile_load_preferences_failed':
        return context.l10n.errorProfileLoadPreferencesFailed;
      case 'profile_update_preferences_failed':
        return context.l10n.errorProfileUpdatePreferencesFailed;
      case 'profile_send_email_code_failed':
        return context.l10n.errorProfileSendEmailCodeFailed;
      case 'profile_send_phone_code_failed':
        return context.l10n.errorProfileSendPhoneCodeFailed;
      case 'follow_failed':
        return context.l10n.errorFollowFailed;
      case 'unfollow_failed':
        return context.l10n.errorUnfollowFailed;
      case 'iap_not_available_web':
        return context.l10n.errorIapNotAvailableWeb;
      case 'iap_store_not_available':
        return context.l10n.errorIapStoreNotAvailable;
      case 'iap_load_products_failed':
        return context.l10n.errorIapLoadProductsFailed;
      case 'iap_verification_failed':
        return context.l10n.errorIapVerificationFailed;
      case 'iap_purchase_failed':
        return context.l10n.errorIapPurchaseFailed;
      case 'You have already reviewed this task.':
        return context.l10n.taskDetailTaskAlreadyReviewed;
      case 'Task is not completed yet.':
        return context.l10n.errorReviewTaskNotCompleted;
      case 'You are not a participant of this task.':
        return context.l10n.errorReviewNotParticipant;
      case 'newbie_task_not_completed':
        return context.l10n.errorNewbieTaskNotCompleted;
      case 'newbie_task_already_claimed':
        return context.l10n.errorNewbieTaskAlreadyClaimed;
      case 'newbie_task_claim_failed':
        return context.l10n.errorNewbieTaskClaimFailed;
      case 'newbie_stage_claim_failed':
        return context.l10n.errorNewbieStageClaimFailed;
      case 'official_task_max_reached':
        return context.l10n.errorOfficialTaskMaxReached;
      case 'official_task_expired':
        return context.l10n.errorOfficialTaskExpired;
      case 'newbie_tasks_load_failed':
        return context.l10n.errorNewbieTasksLoadFailed;
      case 'leaderboard_load_failed':
        return context.l10n.errorLeaderboardLoadFailed;
      case 'badges_load_failed':
        return context.l10n.errorBadgesLoadFailed;
      // Expert dashboard action messages
      case 'expertServiceSubmitted':
        return context.l10n.expertServiceSubmitted;
      case 'expertServiceUpdated':
        return context.l10n.expertServiceUpdated;
      case 'expertServiceDeleted':
        return context.l10n.expertServiceDeleted;
      case 'expertTimeSlotCreated':
        return context.l10n.expertTimeSlotCreated;
      case 'expertTimeSlotDeleted':
        return context.l10n.expertTimeSlotDeleted;
      case 'expertScheduleMarkedRest':
        return context.l10n.expertScheduleClosedAdded;
      case 'expertScheduleUnmarked':
        return context.l10n.expertScheduleClosedRemoved;
      case 'expertProfileUpdateSubmitted':
        return context.l10n.expertProfileEditSubmitted;
      case 'user_profile_load_failed':
        return context.l10n.userProfileLoadFailed;
      case 'user_profile_update_failed':
        return context.l10n.userProfileUpdateFailed;
      case 'user_profile_delete_failed':
        return context.l10n.userProfileDeleteFailed;
      case 'task_statistics_load_failed':
        return context.l10n.errorTaskStatisticsLoadFailed;
      case 'onboarding_submit_failed':
        return context.l10n.onboardingSubmitFailed;
      case 'service_created':
        return context.l10n.personalServiceCreated;
      case 'service_updated':
        return context.l10n.personalServiceUpdated;
      case 'service_deleted':
        return context.l10n.personalServiceDeleted;
      case 'ai_optimize_failed':
        return context.l10n.errorAiOptimizeFailed;
      default:
        // 服务端返回的已翻译消息，直接使用
        return errorMessage;
    }
  }
}
