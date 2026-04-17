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
      case 'INVALID_CREDENTIALS':
        return context.l10n.errorInvalidCredentials;
      case 'ACCOUNT_SUSPENDED':
        return context.l10n.errorAccountSuspended;
      case 'ACCOUNT_BANNED':
        return context.l10n.errorAccountBanned;
      case 'CAPTCHA_FAILED':
        return context.l10n.errorCaptchaFailed;
      case 'CODE_ATTEMPT_LIMIT':
        return context.l10n.errorCodeAttemptLimit;
      case 'INVALID_PHONE_FORMAT':
        return context.l10n.errorInvalidPhoneFormat;
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
      case 'flea_market_error_rental_request_failed':
      case 'flea_market_error_submit_rental_request_failed':
        return context.l10n.fleaMarketErrorRentalRequestFailed;
      case 'flea_market_error_approve_rental_failed':
        return context.l10n.fleaMarketErrorApproveRentalFailed;
      case 'flea_market_error_reject_rental_failed':
        return context.l10n.fleaMarketErrorRejectRentalFailed;
      case 'flea_market_error_counter_offer_rental_failed':
      case 'flea_market_error_rental_counter_offer_failed':
        return context.l10n.fleaMarketErrorCounterOfferRentalFailed;
      case 'flea_market_error_confirm_return_failed':
        return context.l10n.fleaMarketErrorConfirmReturnFailed;
      case 'flea_market_error_get_rental_detail_failed':
        return context.l10n.fleaMarketErrorGetRentalDetailFailed;
      case 'flea_market_error_get_rental_requests_failed':
        return context.l10n.fleaMarketErrorGetRentalRequestsFailed;
      case 'flea_market_error_respond_rental_counter_offer_failed':
        return context.l10n.fleaMarketErrorCounterOfferRentalFailed;
      case 'flea_market_error_get_my_rentals_failed':
      case 'my_posts_rentals_load_failed':
        return context.l10n.fleaMarketErrorGetRentalRequestsFailed;
      case 'flea_market_error_not_rental_item':
        return context.l10n.fleaMarketErrorNotRentalItem;
      case 'flea_market_error_cannot_rent_own_item':
        return context.l10n.fleaMarketErrorCannotRentOwnItem;
      case 'flea_market_error_rental_payment_expired':
        return context.l10n.fleaMarketErrorRentalPaymentExpired;
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
      case 'skill_feed_load_failed':
        return context.l10n.skillFeedLoadFailed;
      case 'skill_feed_load_more_failed':
        return context.l10n.skillFeedLoadMoreFailed;
      // Expert dashboard action messages
      case 'expertServiceSubmitted':
        return context.l10n.expertServiceSubmitted;
      case 'expertServiceUpdated':
        return context.l10n.expertServiceUpdated;
      case 'expertServiceDeleted':
        return context.l10n.expertServiceDeleted;
      case 'expertServiceActivated':
        return context.l10n.expertServiceActivated;
      case 'expertServiceDeactivated':
        return context.l10n.expertServiceDeactivated;
      case 'expert_dashboard_load_my_tasks_failed':
        return context.l10n.errorLoadFailedMessage;
      case 'expertTimeSlotCreated':
        return context.l10n.expertTimeSlotCreated;
      case 'expertTimeSlotDeleted':
        return context.l10n.expertTimeSlotDeleted;
      case 'expertScheduleMarkedRest':
        return context.l10n.expertScheduleClosedAdded;
      case 'expertScheduleUnmarked':
        return context.l10n.expertScheduleClosedRemoved;
      case 'expertBusinessHoursUpdated':
        return context.l10n.expertBusinessHoursSaved;
      case 'expert_dashboard_no_team':
        return context.l10n.expertDashboardNoTeam;
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
      // Expert Team
      case 'expert_team_apply_submitted': return context.l10n.expertTeamApplySubmitted;
      case 'expert_team_invite_sent': return context.l10n.expertTeamInviteSent;
      case 'expert_team_joined': return context.l10n.expertTeamJoined;
      case 'expert_team_invite_rejected': return context.l10n.expertTeamInviteRejected;
      case 'expert_team_join_requested': return context.l10n.expertTeamJoinRequested;
      case 'expert_team_join_approved': return context.l10n.expertTeamJoinApproved;
      case 'expert_team_join_rejected': return context.l10n.expertTeamJoinRejected;
      case 'expert_team_role_updated': return context.l10n.expertTeamRoleUpdated;
      case 'expert_team_member_removed': return context.l10n.expertTeamMemberRemoved;
      case 'expert_team_ownership_transferred': return context.l10n.expertTeamOwnershipTransferred;
      case 'expert_team_left': return context.l10n.expertTeamLeft;
      case 'expert_team_followed': return context.l10n.expertTeamFollowed;
      case 'expert_team_unfollowed': return context.l10n.expertTeamUnfollowed;
      case 'expert_team_service_created': return context.l10n.expertTeamServiceCreated;
      case 'expert_team_service_deleted': return context.l10n.expertTeamServiceDeleted;
      case 'expert_team_dissolved': return context.l10n.expertTeamDissolved;
      case 'expert_team_applications_enabled': return context.l10n.expertTeamApplicationsEnabled;
      case 'expert_team_applications_disabled': return context.l10n.expertTeamApplicationsDisabled;
      case 'expert_team_group_buy_joined': return context.l10n.expertTeamGroupBuyJoined;
      case 'expert_team_group_buy_cancelled': return context.l10n.expertTeamGroupBuyCancelled;
      case 'expert_team_package_used': return context.l10n.expertTeamPackageUsed;
      case 'expert_team_coupon_created': return context.l10n.expertTeamCouponCreated;
      case 'expert_team_coupon_deactivated': return context.l10n.expertTeamCouponDeactivated;
      case 'expert_team_review_replied': return context.l10n.expertTeamReviewReplied;
      // 时间段容量已满 (后端 expert_consultation_routes.apply_for_service 返回)
      case 'time_slot_full': return context.l10n.expertTimeSlotFull;
      // 团队 stripe 未就绪 / 货币不支持 (resolve_task_taker)
      case 'expert_stripe_not_ready': return context.l10n.expertStripeNotReady;
      case 'expert_currency_unsupported': return context.l10n.expertCurrencyUnsupported;
      // bundle 套餐校验
      case 'bundle_service_not_found':
      case 'bundle_service_deleted':
      case 'bundle_nested':
      case 'bundle_self_reference':
        return context.l10n.expertBundleInvalid;
      // A1 套餐购买/核销
      case 'package_already_active':
        return context.l10n.errorPackageAlreadyActive;
      case 'package_expired':
        return context.l10n.errorPackageExpired;
      case 'bundle_sub_service_required':
        return context.l10n.errorPackageBundleSubRequired;
      case 'team_no_stripe_account':
        return context.l10n.errorTeamNoStripeAccount;
      // 服务删除前置校验
      case 'service_has_active_activities':
        return context.l10n.errorServiceHasActiveActivities;
      case 'service_has_active_applications':
        return context.l10n.errorServiceHasActiveApplications;
      // Expert / team 相关后端错误码
      case 'activity_type_unsupported':
        return context.l10n.errorActivityTypeUnsupported;
      case 'ambiguous_expert_team':
        return context.l10n.errorAmbiguousExpertTeam;
      case 'expert_owner_missing':
        return context.l10n.errorExpertOwnerMissing;
      case 'service_not_found':
        return context.l10n.errorServiceNotFound;
      case 'service_not_owned_by_team':
        return context.l10n.errorServiceNotOwnedByTeam;
      case 'service_inactive':
        return context.l10n.errorServiceInactive;
      case 'package_price_missing':
        return context.l10n.errorPackagePriceMissing;
      case 'discount_too_deep':
        return context.l10n.errorDiscountTooDeep;
      case 'discount_not_lower':
        return context.l10n.errorDiscountNotLower;
      case 'team_not_found':
        return context.l10n.errorTeamNotFound;
      case 'team_stripe_not_ready':
        return context.l10n.expertStripeNotReady;
      case 'team_payout_failed':
        return context.l10n.errorTeamPayoutFailed;
      case 'unknown_owner_type':
        return context.l10n.errorUnknownOwnerType;
      // 中间件级别错误码（偶尔透传到 UI）
      case 'admin_origin_denied':
      case 'admin_ip_denied':
      case 'ADMIN_ORIGIN_DENIED':
      case 'ADMIN_IP_DENIED':
        return context.l10n.errorAdminAccessDenied;
      case 'admin_rate_limit':
      case 'ADMIN_RATE_LIMIT':
        return context.l10n.errorRateLimited;
      case 'auth_failed':
      case 'mobile_auth_failed':
        return context.l10n.errorAuthFailed;
      // A1 套餐购买 / 核销 新错误码 (package_purchase_routes)
      case 'package_not_found':
        return context.l10n.errorPackageNotFound;
      case 'package_not_found_or_inactive':
        return context.l10n.errorPackageNotFoundOrInactive;
      case 'package_not_found_or_not_team':
        return context.l10n.errorPackageNotFoundOrNotTeam;
      case 'package_exhausted':
        return context.l10n.errorPackageExhausted;
      case 'package_price_not_set':
        return context.l10n.errorPackagePriceNotSet;
      case 'service_not_package':
        return context.l10n.errorServiceNotPackage;
      case 'personal_service_no_package':
        return context.l10n.errorPersonalServiceNoPackage;
      case 'service_team_resolve_failed':
        return context.l10n.errorServiceTeamResolveFailed;
      case 'qr_or_otp_required':
        return context.l10n.errorQrOrOtpRequired;
      case 'qr_invalid_or_expired':
        return context.l10n.errorQrInvalidOrExpired;
      case 'otp_invalid_or_expired':
        return context.l10n.errorOtpInvalidOrExpired;
      case 'package_id_invalid':
        return context.l10n.errorSubServiceIdInvalid;
      case 'sub_service_id_invalid':
        return context.l10n.errorSubServiceIdInvalid;
      case 'sub_service_required':
        return context.l10n.errorPackageBundleSubRequired;
      case 'sub_service_not_in_bundle':
        return context.l10n.errorSubServiceNotInBundle;
      case 'sub_service_exhausted':
        return context.l10n.errorSubServiceExhausted;
      case 'multi_total_sessions_invalid':
        return context.l10n.errorMultiTotalSessionsInvalid;
      case 'expert_bundle_invalid':
        return context.l10n.expertBundleInvalid;
      case 'stripe_create_failed':
        return context.l10n.errorStripeCreateFailed;
      case 'package_purchase_failed':
        return context.l10n.errorPackagePurchaseFailed;
      // 套餐退款 / 评价 / 争议 错误码
      case 'package_already_exhausted':
        return context.l10n.errorPackageAlreadyExhausted;
      case 'package_disputed':
        return context.l10n.errorPackageDisputed;
      case 'package_already_refunded':
        return context.l10n.errorPackageAlreadyRefunded;
      case 'package_already_released':
        return context.l10n.errorPackageAlreadyReleased;
      case 'package_cancelled':
        return context.l10n.errorPackageCancelled;
      case 'package_refunded':
        return context.l10n.errorPackageRefunded;
      case 'sub_service_deleted':
        return context.l10n.errorSubServiceDeleted;
      case 'package_not_active':
        return context.l10n.errorPackageNotActive;
      case 'package_not_reviewable':
        return context.l10n.errorPackageNotReviewable;
      case 'invalid_rating':
        return context.l10n.errorInvalidRating;
      case 'review_already_exists':
        return context.l10n.errorReviewAlreadyExists;
      case 'reason_required':
        return context.l10n.errorReasonRequired;
      case 'package_never_used_use_refund':
        return context.l10n.errorPackageNeverUsedUseRefund;
      // ── Expert activity creation / draw errors ──
      case 'service_required_for_standard':
        return context.l10n.errorServiceRequiredForStandard;
      case 'activity_type_invalid':
        return context.l10n.errorActivityTypeInvalid;
      case 'prize_type_required':
        return context.l10n.errorPrizeTypeRequired;
      case 'prize_type_invalid':
        return context.l10n.errorPrizeTypeInvalid;
      case 'prize_count_required':
        return context.l10n.errorPrizeCountRequired;
      case 'draw_mode_required':
        return context.l10n.errorDrawModeRequired;
      case 'draw_trigger_required':
        return context.l10n.errorDrawTriggerRequired;
      case 'draw_at_required':
        return context.l10n.errorDrawAtRequired;
      case 'draw_participant_count_required':
        return context.l10n.errorDrawParticipantCountRequired;
      case 'max_participants_required':
        return context.l10n.errorMaxParticipantsRequired;
      case 'not_lottery':
        return context.l10n.errorNotLottery;
      case 'already_drawn':
        return context.l10n.errorAlreadyDrawn;
      case 'activity_not_open':
        return context.l10n.errorActivityNotOpen;
      case 'expert_dashboard_load_activities_failed':
        return context.l10n.errorLoadActivitiesFailed;
      default:
        // 服务端返回的已翻译消息，直接使用
        return errorMessage;
    }
  }
}
