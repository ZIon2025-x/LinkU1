import Foundation

/// 本地化辅助工具 - 企业级多语言支持
public struct LocalizationHelper {
    
    /// 当前语言代码
    public static var currentLanguage: String {
        Locale.current.language.languageCode?.identifier ?? "en"
    }
    
    /// 当前区域代码
    public static var currentRegion: String {
        Locale.current.region?.identifier ?? "US"
    }
    
    /// 当前语言标识符
    public static var currentLocale: String {
        return Locale.current.identifier
    }
    
    /// 获取本地化字符串
    public static func localized(
        _ key: String,
        tableName: String? = nil,
        bundle: Bundle = .main,
        comment: String = ""
    ) -> String {
        return NSLocalizedString(key, tableName: tableName, bundle: bundle, comment: comment)
    }
    
    /// 获取本地化字符串（带参数）
    public static func localized(
        _ key: String,
        arguments: CVarArg...,
        tableName: String? = nil,
        bundle: Bundle = .main
    ) -> String {
        let format = localized(key, tableName: tableName, bundle: bundle)
        return String(format: format, arguments: arguments)
    }
    
    /// 获取本地化字符串（带单个参数）
    public static func localized(
        _ key: String,
        argument: CVarArg,
        tableName: String? = nil,
        bundle: Bundle = .main
    ) -> String {
        let format = localized(key, tableName: tableName, bundle: bundle)
        return String(format: format, argument)
    }
    
    /// 检查是否支持语言
    public static func isLanguageSupported(_ languageCode: String) -> Bool {
        let supportedLanguages = ["en", "zh-Hans", "zh-Hant"]
        return supportedLanguages.contains(languageCode)
    }
    
    /// 获取支持的语言列表
    public static var supportedLanguages: [String] {
        return ["en", "zh-Hans", "zh-Hant"]
    }
}

/// 本地化键 - 完整的应用本地化键枚举
public enum LocalizationKey: String {
    // MARK: - Common
    case commonOk = "common.ok"
    case commonCancel = "common.cancel"
    case commonConfirm = "common.confirm"
    case commonDelete = "common.delete"
    case commonSave = "common.save"
    case commonEdit = "common.edit"
    case commonClose = "common.close"
    case commonRetry = "common.retry"
    case commonLoading = "common.loading"
    case commonSearch = "common.search"
    case commonClear = "common.clear"
    case commonSubmit = "common.submit"
    case commonBack = "common.back"
    case commonNext = "common.next"
    case commonFinish = "common.finish"
    case commonDone = "common.done"
    case commonShare = "common.share"
    case commonMore = "common.more"
    case commonViewAll = "common.view_all"
    case commonLoadingImage = "common.loading_image"
    case commonFilter = "common.filter"
    case commonAll = "common.all"
    case commonNotProvided = "common.not_provided"
    case commonLoadMore = "common.load_more"
    
    // MARK: - App
    case appName = "app.name"
    case appTagline = "app.tagline"
    case appUser = "app.user"
    case appTermsOfService = "app.terms_of_service"
    case appPrivacyPolicy = "app.privacy_policy"
    case appAbout = "app.about"
    case appVersion = "app.version"
    
    // MARK: - Auth
    case authLogin = "auth.login"
    case authRegister = "auth.register"
    case authLogout = "auth.logout"
    case authEmail = "auth.email"
    case authEmailOrId = "auth.email_or_id"
    case authPassword = "auth.password"
    case authPhone = "auth.phone"
    case authVerificationCode = "auth.verification_code"
    case authSendCode = "auth.send_code"
    case authResendCode = "auth.resend_code"
    case authLoginMethod = "auth.login_method"
    case authEmailPassword = "auth.email_password"
    case authEmailCode = "auth.email_code"
    case authPhoneCode = "auth.phone_code"
    case authEnterEmail = "auth.enter_email"
    case authEnterEmailOrId = "auth.enter_email_or_id"
    case authEnterPassword = "auth.enter_password"
    case authEnterPhone = "auth.enter_phone"
    case authEnterCode = "auth.enter_code"
    case authNoAccount = "auth.no_account"
    case authHasAccount = "auth.has_account"
    case authRegisterNow = "auth.register_now"
    case authLoginNow = "auth.login_now"
    case authNoAccountUseCode = "auth.no_account_use_code"
    case authRegisterSuccess = "auth.register_success"
    case authCaptchaTitle = "auth.captcha_title"
    case authCaptchaMessage = "auth.captcha_message"
    case authCaptchaError = "auth.captcha_error"
    case authUsername = "auth.username"
    case authEnterUsername = "auth.enter_username"
    case authPasswordHint = "auth.password_hint"
    case authPhoneOptional = "auth.phone_optional"
    case authAgreeToTerms = "auth.agree_to_terms"
    case authTermsOfService = "auth.terms_of_service"
    case authPrivacyPolicy = "auth.privacy_policy"
    case authLoginLater = "auth.login_later"
    
    // MARK: - Home
    case homeExperts = "home.experts"
    case homeRecommended = "home.recommended"
    case homeNearby = "home.nearby"
    case homeGreeting = "home.greeting"
    case homeWhatToDo = "home.what_to_do"
    case homeMenu = "home.menu"
    case homeSearchExperts = "home.search_experts"
    case homeSearch = "home.search"
    case homeNoResults = "home.no_results"
    case homeTryOtherKeywords = "home.try_other_keywords"
    case homeSearchHistory = "home.search_history"
    case homeHotSearches = "home.hot_searches"
    case homeNoNearbyTasks = "home.no_nearby_tasks"
    case homeNoNearbyTasksMessage = "home.no_nearby_tasks_message"
    case homeNoExperts = "home.no_experts"
    case homeNoExpertsMessage = "home.no_experts_message"
    case homeRecommendedTasks = "home.recommended_tasks"
    case homeNoRecommendedTasks = "home.no_recommended_tasks"
    case homeNoRecommendedTasksMessage = "home.no_recommended_tasks_message"
    case homeLatestActivity = "home.latest_activity"
    case homeNoActivity = "home.no_activity"
    case homeNoActivityMessage = "home.no_activity_message"
    case homeNoMoreActivity = "home.no_more_activity"
    case homeHotEvents = "home.hot_events"
    case homeNoEvents = "home.no_events"
    case homeNoEventsMessage = "home.no_events_message"
    case homeViewEvent = "home.view_event"
    case homeTapToViewEvents = "home.tap_to_view_events"
    case homeMultiplePeople = "home.multiple_people"
    case homeView = "home.view"
    
    // MARK: - Tasks
    case tasksTaskDetail = "tasks.task_detail"
    case tasksLoadFailed = "tasks.load_failed"
    case tasksCancelTask = "tasks.cancel_task"
    case tasksCancelTaskConfirm = "tasks.cancel_task_confirm"
    case tasksApply = "tasks.apply"
    case tasksApplyTask = "tasks.apply_task"
    case tasksApplyMessage = "tasks.apply_message"
    case tasksApplyInfo = "tasks.apply_info"
    case tasksPriceNegotiation = "tasks.price_negotiation"
    case tasksApplyHint = "tasks.apply_hint"
    case tasksSubmitApplication = "tasks.submit_application"
    case tasksNoApplicants = "tasks.no_applicants"
    case tasksApplicantsList = "tasks.applicants_list"
    case tasksMessageLabel = "tasks.message_label"
    case tasksTaskDescription = "tasks.task_description"
    case tasksTimeInfo = "tasks.time_info"
    case tasksPublishTime = "tasks.publish_time"
    case tasksDeadline = "tasks.deadline"
    case tasksPublisher = "tasks.publisher"
    case tasksYourTask = "tasks.your_task"
    case tasksManageTask = "tasks.manage_task"
    case tasksReviews = "tasks.reviews"
    case tasksNoTaskImages = "tasks.no_task_images"
    case tasksPointsReward = "tasks.points_reward"
    case tasksShareTo = "tasks.share_to"
    case tasksTask = "tasks.task"
    case tasksTasks = "tasks.tasks"
    case tasksMyTasks = "tasks.my_tasks"
    
    // MARK: - Task Experts
    case expertsExperts = "experts.experts"
    case expertsBecomeExpert = "experts.become_expert"
    case expertsSearchExperts = "experts.search_experts"
    case expertsApplyNow = "experts.apply_now"
    case expertsLoginToApply = "experts.login_to_apply"
    
    // MARK: - Forum
    case forumForum = "forum.forum"
    case forumAllPosts = "forum.all_posts"
    case forumNoPosts = "forum.no_posts"
    case forumNoPostsMessage = "forum.no_posts_message"
    case forumSearchPosts = "forum.search_posts"
    case forumPosts = "forum.posts"
    case forumPostLoadFailed = "forum.post_load_failed"
    case forumOfficial = "forum.official"
    case forumAllReplies = "forum.all_replies"
    case forumReply = "forum.reply"
    case forumWriteReply = "forum.write_reply"
    case forumSend = "forum.send"
    case forumView = "forum.view"
    case forumLike = "forum.like"
    case forumFavorite = "forum.favorite"
    
    // MARK: - Flea Market
    case fleaMarketFleaMarket = "flea_market.flea_market"
    case fleaMarketSubtitle = "flea_market.subtitle"
    case fleaMarketNoItems = "flea_market.no_items"
    case fleaMarketNoItemsMessage = "flea_market.no_items_message"
    case fleaMarketSearchItems = "flea_market.search_items"
    case fleaMarketItems = "flea_market.items"
    
    // MARK: - Profile
    case profileProfile = "profile.profile"
    case profileMyTasks = "profile.my_tasks"
    case profileMyPosts = "profile.my_posts"
    case profileSettings = "profile.settings"
    case profileAbout = "profile.about"
    case profileLogout = "profile.logout"
    case profileLogoutConfirm = "profile.logout_confirm"
    
    // MARK: - Messages
    case messagesMessages = "messages.messages"
    case messagesChat = "messages.chat"
    case messagesSend = "messages.send"
    case messagesEnterMessage = "messages.enter_message"
    
    // MARK: - Leaderboard
    case leaderboardLeaderboard = "leaderboard.leaderboard"
    case leaderboardRank = "leaderboard.rank"
    case leaderboardPoints = "leaderboard.points"
    case leaderboardUser = "leaderboard.user"
    case leaderboardLoadFailed = "leaderboard.load_failed"
    case leaderboardSortComprehensive = "leaderboard.sort_comprehensive"
    case leaderboardSortNetVotes = "leaderboard.sort_net_votes"
    case leaderboardSortUpvotes = "leaderboard.sort_upvotes"
    case leaderboardSortLatest = "leaderboard.sort_latest"
    case leaderboardNoItems = "leaderboard.no_items"
    case leaderboardNoItemsMessage = "leaderboard.no_items_message"
    
    // MARK: - Notifications
    case notificationsNotifications = "notifications.notifications"
    case notificationsNoNotifications = "notifications.no_notifications"
    case notificationsMarkAllRead = "notifications.mark_all_read"
    case notificationEnableNotification = "notification.enable_notification"
    case notificationEnableNotificationTitle = "notification.enable_notification_title"
    case notificationEnableNotificationMessage = "notification.enable_notification_message"
    case notificationEnableNotificationDescription = "notification.enable_notification_description"
    case notificationAllowNotification = "notification.allow_notification"
    case notificationNotNow = "notification.not_now"
    
    // MARK: - Student Verification
    case studentVerificationVerification = "student_verification.verification"
    case studentVerificationSubmit = "student_verification.submit"
    case studentVerificationUploadDocument = "student_verification.upload_document"
    case studentVerificationEmailInfo = "student_verification.email_info"
    case studentVerificationSchoolEmail = "student_verification.school_email"
    case studentVerificationSchoolEmailPlaceholder = "student_verification.school_email_placeholder"
    case studentVerificationRenewVerification = "student_verification.renew_verification"
    case studentVerificationChangeEmail = "student_verification.change_email"
    case studentVerificationSubmitVerification = "student_verification.submit_verification"
    case studentVerificationStudentVerificationTitle = "student_verification.student_verification_title"
    case studentVerificationDescription = "student_verification.description"
    case studentVerificationStartVerification = "student_verification.start_verification"
    case studentVerificationStatus = "student_verification.status"
    case studentVerificationEmailInstruction = "student_verification.email_instruction"
    case studentVerificationRenewInfo = "student_verification.renew_info"
    case studentVerificationRenewEmailPlaceholder = "student_verification.renew_email_placeholder"
    case studentVerificationRenewInstruction = "student_verification.renew_instruction"
    case studentVerificationNewSchoolEmail = "student_verification.new_school_email"
    case studentVerificationNewSchoolEmailPlaceholder = "student_verification.new_school_email_placeholder"
    case studentVerificationChangeEmailInstruction = "student_verification.change_email_instruction"
    case studentVerificationBenefitCampusLife = "student_verification.benefit_campus_life"
    case studentVerificationBenefitCampusLifeDescription = "student_verification.benefit_campus_life_description"
    case studentVerificationBenefitStudentCommunity = "student_verification.benefit_student_community"
    case studentVerificationBenefitStudentCommunityDescription = "student_verification.benefit_student_community_description"
    case studentVerificationBenefitExclusiveBenefits = "student_verification.benefit_exclusive_benefits"
    case studentVerificationBenefitExclusiveBenefitsDescription = "student_verification.benefit_exclusive_benefits_description"
    case studentVerificationBenefitVerificationBadge = "student_verification.benefit_verification_badge"
    case studentVerificationBenefitVerificationBadgeDescription = "student_verification.benefit_verification_badge_description"
    
    // MARK: - Customer Service
    case customerServiceCustomerService = "customer_service.customer_service"
    case customerServiceChatWithService = "customer_service.chat_with_service"
    
    // MARK: - Activity
    case activityActivity = "activity.activity"
    case activityRecentActivity = "activity.recent_activity"
    case activityPoster = "activity.poster"
    case activityViewExpertProfile = "activity.view_expert_profile"
    case activityFavorite = "activity.favorite"
    case activityTimeFlexible = "activity.time_flexible"
    case activityTimeFlexibleMessage = "activity.time_flexible_message"
    case activityPreferredDate = "activity.preferred_date"
    case activityConfirmApply = "activity.confirm_apply"
    case activityApplyToJoin = "activity.apply_to_join"
    
    // MARK: - Search
    case searchSearch = "search.search"
    case searchResults = "search.results"
    case searchNoResults = "search.no_results"
    case searchTryOtherKeywords = "search.try_other_keywords"
    case searchPlaceholder = "search.placeholder"
    case searchTaskPlaceholder = "search.task_placeholder"
    
    // MARK: - Task Application
    case taskApplicationAdvantagePlaceholder = "task_application.advantage_placeholder"
    case taskApplicationReviewPlaceholder = "task_application.review_placeholder"
    
    // MARK: - Notification
    case notificationAgree = "notification.agree"
    case notificationReject = "notification.reject"
    case notificationNoNotifications = "notification.no_notifications"
    case notificationNoNotificationsMessage = "notification.no_notifications_message"
    
    // MARK: - Profile
    case profileName = "profile.name"
    case profileEnterName = "profile.enter_name"
    case profileEmail = "profile.email"
    case profileEnterEmail = "profile.enter_email"
    case profileEnterNewEmail = "profile.enter_new_email"
    case profileVerificationCode = "profile.verification_code"
    case profileEnterVerificationCode = "profile.enter_verification_code"
    case profilePhone = "profile.phone"
    case profileEnterPhone = "profile.enter_phone"
    case profileEnterNewPhone = "profile.enter_new_phone"
    
    // MARK: - Payment
    case paymentNoPayoutRecords = "payment.no_payout_records"
    case paymentNoPayoutRecordsMessage = "payment.no_payout_records_message"
    case paymentViewDetails = "payment.view_details"
    case paymentPayout = "payment.payout"
    case paymentNoAvailableBalance = "payment.no_available_balance"
    case paymentPayoutRecords = "payment.payout_records"
    case paymentTotalBalance = "payment.total_balance"
    case paymentAvailableBalance = "payment.available_balance"
    case paymentPending = "payment.pending"
    case paymentPayoutAmount = "payment.payout_amount"
    case paymentNoteOptional = "payment.note_optional"
    case paymentConfirmPayout = "payment.confirm_payout"
    case paymentAccountInfo = "payment.account_info"
    case paymentOpenStripeDashboard = "payment.open_stripe_dashboard"
    case paymentExternalAccount = "payment.external_account"
    case paymentNoExternalAccount = "payment.no_external_account"
    case paymentDetails = "payment.details"
    case paymentPayoutNote = "payment.payout_note"
    case paymentAccountDetails = "payment.account_details"
    case paymentAccountId = "payment.account_id"
    case paymentDisplayName = "payment.display_name"
    case paymentCountry = "payment.country"
    case paymentAccountType = "payment.account_type"
    case paymentDetailsSubmitted = "payment.details_submitted"
    case paymentChargesEnabled = "payment.charges_enabled"
    case paymentPayoutsEnabled = "payment.payouts_enabled"
    case paymentYes = "payment.yes"
    case paymentNo = "payment.no"
    case paymentBankAccount = "payment.bank_account"
    case paymentCard = "payment.card"
    case paymentBankName = "payment.bank_name"
    case paymentAccountLast4 = "payment.account_last4"
    case paymentRoutingNumber = "payment.routing_number"
    case paymentAccountHolder = "payment.account_holder"
    case paymentHolderType = "payment.holder_type"
    case paymentIndividual = "payment.individual"
    case paymentCompany = "payment.company"
    case paymentStatus = "payment.status"
    case paymentCardBrand = "payment.card_brand"
    case paymentCardLast4 = "payment.card_last4"
    case paymentExpiry = "payment.expiry"
    case paymentCardType = "payment.card_type"
    case paymentCreditCard = "payment.credit_card"
    case paymentDebitCard = "payment.debit_card"
    case paymentPayoutAmountTitle = "payment.payout_amount_title"
    case paymentIncomeAmount = "payment.income_amount"
    case paymentTransactionId = "payment.transaction_id"
    case paymentDescription = "payment.description"
    case paymentTime = "payment.time"
    case paymentType = "payment.type"
    case paymentIncome = "payment.income"
    case paymentSource = "payment.source"
    case paymentPayoutManagement = "payment.payout_management"
    case paymentTransactionDetails = "payment.transaction_details"
    case paymentAccountSetupComplete = "payment.account_setup_complete"
    case paymentCanReceiveRewards = "payment.can_receive_rewards"
    case paymentAccountInfoBelow = "payment.account_info_below"
    case paymentRefreshAccountInfo = "payment.refresh_account_info"
    case paymentComplete = "payment.complete"
    
    // MARK: - Student Verification (Extended)
    case studentVerificationEmail = "student_verification.verification_email"
    case studentVerificationTime = "student_verification.verification_time"
    case studentVerificationExpiryTime = "student_verification.expiry_time"
    case studentVerificationDaysRemaining = "student_verification.days_remaining"
    case studentVerificationDaysFormat = "student_verification.days_format"
    
    // MARK: - Leaderboard (Extended)
    case leaderboardItemCount = "leaderboard.item_count"
    case leaderboardTotalVotes = "leaderboard.total_votes"
    case leaderboardViewCount = "leaderboard.view_count"
    
    // MARK: - Profile (Extended)
    case profileClickToChangeAvatar = "profile.click_to_change_avatar"
    case profileEditProfile = "profile.edit_profile"
    case profileUpdated = "profile.updated"
    
    // MARK: - Task Expert
    case taskExpertApplied = "task_expert.applied"
    case taskExpertByAppointment = "task_expert.by_appointment"
    
    // MARK: - Translation
    case translationTranslating = "translation.translating"
    case translationTranslate = "translation.translate"
    case translationShowTranslation = "translation.show_translation"
    case translationShowOriginal = "translation.show_original"
    
    // MARK: - Auth (Extended)
    case authCountdownSeconds = "auth.countdown_seconds"
    
    // MARK: - Errors
    case errorNetworkError = "error.network_error"
    case errorUnknownError = "error.unknown_error"
    case errorInvalidInput = "error.invalid_input"
    case errorLoginFailed = "error.login_failed"
    case errorRegisterFailed = "error.register_failed"
    case errorOperationFailed = "error.operation_failed"
    
    // MARK: - Success
    case successOperationSuccess = "success.operation_success"
    case successSaved = "success.saved"
    case successDeleted = "success.deleted"
    case successRefreshSuccess = "success.refresh_success"
    case successRefreshSuccessMessage = "success.refresh_success_message"
    
    // MARK: - Currency
    case currencyPound = "currency.pound"
    case currencyPoints = "currency.points"
    
    // MARK: - Points (Extended)
    case pointsPoints = "points.points"
    case pointsPointsAndPayment = "points.points_and_payment"
    case pointsPointsDeduction = "points.points_deduction"
    case pointsCheckIn = "points.check_in"
    case pointsCheckedInToday = "points.checked_in_today"
    case pointsCheckInReward = "points.check_in_reward"
    case pointsCheckInDescription = "points.check_in_description"
    case pointsTransactionHistory = "points.transaction_history"
    case pointsNoTransactionHistory = "points.no_transaction_history"
    case pointsAndCoupons = "points.points_and_coupons"
    case pointsShowRecentOnly = "points.show_recent_only"
    case pointsAmountFormat = "points.amount_format"
    case couponCoupons = "coupon.coupons"
    case couponCheckIn = "coupon.check_in"
    case couponDiscount = "coupon.discount"
    case couponAvailable = "coupon.available"
    case couponMyCoupons = "coupon.my_coupons"
    case couponNoThreshold = "coupon.no_threshold"
    case couponClaimNow = "coupon.claim_now"
    case couponValidUntil = "coupon.valid_until"
    case couponNoAvailableCoupons = "coupon.no_available_coupons"
    case couponNoAvailableCouponsMessage = "coupon.no_available_coupons_message"
    case couponNoMyCoupons = "coupon.no_my_coupons"
    case couponNoMyCouponsMessage = "coupon.no_my_coupons_message"
    case couponUsageInstructions = "coupon.usage_instructions"
    case couponTransactionHistory = "coupon.transaction_history"
    case couponCheckInReward = "coupon.check_in_reward"
    case couponCheckInSuccess = "coupon.check_in_success"
    case couponAwesome = "coupon.awesome"
    case couponDays = "coupon.days"
    case couponRememberTomorrow = "coupon.remember_tomorrow"
    case couponConsecutiveReward = "coupon.consecutive_reward"
    case couponCheckInNow = "coupon.check_in_now"
    case couponConsecutiveDays = "coupon.consecutive_days"
    case couponConsecutiveCheckIn = "coupon.consecutive_check_in"
    
    // MARK: - Wallet
    case walletQuickActions = "wallet.quick_actions"
    case walletPayoutManagement = "wallet.payout_management"
    case walletPayoutManagementSubtitle = "wallet.payout_management_subtitle"
    case walletPaymentRecords = "wallet.payment_records"
    case walletPaymentRecordsSubtitle = "wallet.payment_records_subtitle"
    case walletRecentTransactions = "wallet.recent_transactions"
    case walletBalance = "wallet.balance"
    case walletMyWallet = "wallet.my_wallet"
    
    // MARK: - Settings
    case settingsNotifications = "settings.notifications"
    case settingsAllowNotifications = "settings.allow_notifications"
    case settingsAppearance = "settings.appearance"
    case settingsThemeMode = "settings.theme_mode"
    case settingsMembership = "settings.membership"
    case settingsVIPMembership = "settings.vip_membership"
    case settingsHelpSupport = "settings.help_support"
    case settingsFAQ = "settings.faq"
    case settingsContactSupport = "settings.contact_support"
    case settingsLegal = "settings.legal"
    case settingsAbout = "settings.about"
    case settingsAppName = "settings.app_name"
    case settingsPaymentAccount = "settings.payment_account"
    case settingsSetupPaymentAccount = "settings.setup_payment_account"
    case settingsAccount = "settings.account"
    case settingsUserID = "settings.user_id"
    
    // MARK: - My Tasks
    case myTasksLoadingCompleted = "my_tasks.loading_completed"
    case myTasksNetworkUnavailable = "my_tasks.network_unavailable"
    case myTasksCheckNetwork = "my_tasks.check_network"
    case myTasksNoPendingApplications = "my_tasks.no_pending_applications"
    case myTasksNoPendingApplicationsMessage = "my_tasks.no_pending_applications_message"
    
    // MARK: - My Posts
    case myPostsTitle = "my_posts.title"
    
    // MARK: - Stripe Connect
    case stripeConnectLoadFailed = "stripe_connect.load_failed"
    
    // MARK: - Payment
    case paymentLoadingForm = "payment.loading_form"
    case paymentPreparing = "payment.preparing"
    case paymentSuccess = "payment.success"
    case paymentSuccessMessage = "payment.success_message"
    case paymentError = "payment.error"
    case paymentTaskInfo = "payment.task_info"
    case paymentTaskTitle = "payment.task_title"
    case paymentApplicant = "payment.applicant"
    case paymentTip = "payment.tip"
    case paymentConfirmPayment = "payment.confirm_payment"
    case paymentPreparingPayment = "payment.preparing_payment"
    case paymentPayment = "payment.payment"
    case paymentCancel = "payment.cancel"
    case paymentRetry = "payment.retry"
    case paymentRetryPayment = "payment.retry_payment"
    case paymentCoupons = "payment.coupons"
    case paymentCouponDiscount = "payment.coupon_discount"
    case paymentNoAvailableCoupons = "payment.no_available_coupons"
    case paymentTotalAmount = "payment.total_amount"
    case paymentFinalPayment = "payment.final_payment"
    case paymentMixed = "payment.mixed"
    
    // MARK: - Task Application
    case taskApplicationApplyTask = "task_application.apply_task"
    case taskApplicationIWantToNegotiatePrice = "task_application.i_want_to_negotiate_price"
    case taskApplicationExpectedAmount = "task_application.expected_amount"
    case taskApplicationNegotiatePriceHint = "task_application.negotiate_price_hint"
    case taskApplicationSubmitApplication = "task_application.submit_application"
    case taskApplicationMessage = "task_application.message"
    case taskApplicationMessageToApplicant = "task_application.message_to_applicant"
    case taskApplicationIsNegotiatePrice = "task_application.is_negotiate_price"
    case taskApplicationNegotiateAmount = "task_application.negotiate_amount"
    case taskApplicationSendMessage = "task_application.send_message"
    case taskApplicationUnknownUser = "task_application.unknown_user"
    case taskApplicationApplyInfo = "task_application.apply_info"
    case taskApplicationOverallRating = "task_application.overall_rating"
    case taskApplicationRatingTags = "task_application.rating_tags"
    case taskApplicationRatingContent = "task_application.rating_content"
    
    // MARK: - Create Task
    case createTaskPublishing = "create_task.publishing"
    case createTaskPublishNow = "create_task.publish_now"
    case createTaskPublishTask = "create_task.publish_task"
    
    // MARK: - Student Verification
    case studentVerificationStudentVerification = "student_verification.student_verification"
    
    // MARK: - Stripe Connect
    case stripeConnectSetupAccount = "stripe_connect.setup_account"
    
    // MARK: - Activity
    case activityLoadFailed = "activity.load_failed"
    case activityPleaseRetry = "activity.please_retry"
    case activityDescription = "activity.description"
    case activityDetails = "activity.details"
    case activitySelectTimeSlot = "activity.select_time_slot"
    case activityNoAvailableTime = "activity.no_available_time"
    case activityNoAvailableTimeMessage = "activity.no_available_time_message"
    case activityParticipateTime = "activity.participate_time"
    case activityByAppointment = "activity.by_appointment"
    case activityParticipants = "activity.participants"
    case activityRemainingSlots = "activity.remaining_slots"
    case activityStatus = "activity.status"
    case activityEnded = "activity.ended"
    case activityFull = "activity.full"
    case activityHotRecruiting = "activity.hot_recruiting"
    case activityLocation = "activity.location"
    case activityType = "activity.type"
    case activityTimeArrangement = "activity.time_arrangement"
    case activityMultipleTimeSlots = "activity.multiple_time_slots"
    case activityDeadline = "activity.deadline"
    case activityExclusiveDiscount = "activity.exclusive_discount"
    case activityFilter = "activity.filter"
    case activityAll = "activity.all"
    case activityActive = "activity.active"
    case activityActivities = "activity.activities"
    case activityNoEndedActivities = "activity.no_ended_activities"
    case activityNoEndedActivitiesMessage = "activity.no_ended_activities_message"
    case activityNoActivities = "activity.no_activities"
    case activityNoActivitiesMessage = "activity.no_activities_message"
    case activityFullCapacity = "activity.full_capacity"
    
    // MARK: - Empty States
    case emptyNoTasks = "empty.no_tasks"
    case emptyNoTasksMessage = "empty.no_tasks_message"
    case emptyNoNotifications = "empty.no_notifications"
    case emptyNoNotificationsMessage = "empty.no_notifications_message"
    case emptyNoPaymentRecords = "empty.no_payment_records"
    case emptyNoPaymentRecordsMessage = "empty.no_payment_records_message"
    
    // MARK: - Payment Status
    case paymentStatusSuccess = "payment_status.success"
    case paymentStatusProcessing = "payment_status.processing"
    case paymentStatusFailed = "payment_status.failed"
    case paymentStatusCanceled = "payment_status.canceled"
    case paymentStatusTaskPayment = "payment_status.task_payment"
    case paymentTaskNumber = "payment.task_number"
    
    // MARK: - Notification
    case notificationSystemMessages = "notification.system_messages"
    case notificationViewAllNotifications = "notification.view_all_notifications"
    
    // MARK: - Customer Service (Extended)
    case customerServiceQueuePosition = "customer_service.queue_position"
    case customerServiceEstimatedWait = "customer_service.estimated_wait"
    case customerServiceConversationEndedMessage = "customer_service.conversation_ended_message"
    case customerServiceNewConversation = "customer_service.new_conversation"
    case customerServiceConnecting = "customer_service.connecting"
    case customerServiceEndConversation = "customer_service.end_conversation"
    case customerServiceHistory = "customer_service.history"
    case customerServiceConnected = "customer_service.connected"
    case customerServiceStartNewConversation = "customer_service.start_new_conversation"
    case customerServiceTotalMessages = "customer_service.total_messages"
    case customerServiceRateService = "customer_service.rate_service"
    case customerServiceSkip = "customer_service.skip"
    
    // MARK: - Payment Records
    case paymentRecordsPaymentRecords = "payment_records.payment_records"
    case paymentRecordsLoading = "payment_records.loading"
    case paymentRecordsLoadFailed = "payment_records.load_failed"
    
    // MARK: - Coupon
    case couponMinAmountAvailable = "coupon.min_amount_available"
    
    // MARK: - Task Type
    case taskTypeSuperTask = "task_type.super_task"
    case taskTypeVipTask = "task_type.vip_task"
    
    // MARK: - Error
    case errorError = "error.error"
    case errorRetry = "error.retry"
    case errorSomethingWentWrong = "error.something_went_wrong"
    case errorInvalidURL = "error.invalid_url"
    case errorNetworkConnectionFailed = "error.network_connection_failed"
    case errorRequestTimeout = "error.request_timeout"
    case errorNetworkRequestFailed = "error.network_request_failed"
    case errorInvalidResponse = "error.invalid_response"
    case errorBadRequest = "error.bad_request"
    case errorUnauthorized = "error.unauthorized"
    case errorForbidden = "error.forbidden"
    case errorNotFound = "error.not_found"
    case errorTooManyRequests = "error.too_many_requests"
    case errorServerError = "error.server_error"
    case errorRequestFailed = "error.request_failed"
    case errorDecodingError = "error.decoding_error"
    case errorUnknown = "error.unknown"
    
    // MARK: - Time
    case timeJustNow = "time.just_now"
    case timeMinutesAgo = "time.minutes_ago"
    case timeHoursAgo = "time.hours_ago"
    case timeDaysAgo = "time.days_ago"
    case timeWeeksAgo = "time.weeks_ago"
    case timeMonthsAgo = "time.months_ago"
    case timeYearsAgo = "time.years_ago"
    
    // MARK: - Tabs
    case tabsHome = "tabs.home"
    case tabsCommunity = "tabs.community"
    case tabsCreate = "tabs.create"
    case tabsMessages = "tabs.messages"
    case tabsProfile = "tabs.profile"
    
    // MARK: - Community
    case communityForum = "community.forum"
    case communityLeaderboard = "community.leaderboard"
    
    // MARK: - Post
    case postPinned = "post.pinned"
    case postFeatured = "post.featured"
    case postOfficial = "post.official"
    case postAll = "post.all"
    
    // MARK: - Actions
    case actionsApprove = "actions.approve"
    case actionsReject = "actions.reject"
    case actionsChat = "actions.chat"
    case actionsShare = "actions.share"
    case actionsCancel = "actions.cancel"
    case actionsConfirm = "actions.confirm"
    case actionsSubmit = "actions.submit"
    case actionsLoadingMessages = "actions.loading_messages"
    case actionsNoMessagesYet = "actions.no_messages_yet"
    case actionsStartConversation = "actions.start_conversation"
    case actionsEnterMessage = "actions.enter_message"
    case actionsPrivateMessage = "actions.private_message"
    case actionsProcessing = "actions.processing"
    case actionsMarkComplete = "actions.mark_complete"
    case actionsConfirmComplete = "actions.confirm_complete"
    case actionsContactRecipient = "actions.contact_recipient"
    case actionsContactPoster = "actions.contact_poster"
    case actionsRateTask = "actions.rate_task"
    case actionsCancelTask = "actions.cancel_task"
    case actionsApplyForTask = "actions.apply_for_task"
    case actionsOptionalMessage = "actions.optional_message"
    case actionsNegotiatePrice = "actions.negotiate_price"
    case actionsApplyReasonHint = "actions.apply_reason_hint"
    case actionsSubmitApplication = "actions.submit_application"
    case actionsCancelReason = "actions.cancel_reason"
    case actionsShareTo = "actions.share_to"
    case shareWechat = "share.wechat"
    case shareWechatMoments = "share.wechat_moments"
    case shareQQ = "share.qq"
    case shareQZone = "share.qzone"
    case shareWeibo = "share.weibo"
    case shareSMS = "share.sms"
    case shareCopyLink = "share.copy_link"
    case shareGenerateImage = "share.generate_image"
    case shareShareTo = "share.share_to"
    case shareGeneratingImage = "share.generating_image"
    case shareImage = "share.image"
    case shareShareImage = "share.share_image"
    case shareSaveToPhotos = "share.save_to_photos"
    
    // MARK: - Profile (Extended)
    case profileUser = "profile.user"
    case profileMyTasksSubtitle = "profile.my_tasks_subtitle"
    case profileMyPostsSubtitle = "profile.my_posts_subtitle"
    case profileMyWallet = "profile.my_wallet"
    case profileMyWalletSubtitle = "profile.my_wallet_subtitle"
    case profileMyApplications = "profile.my_applications"
    case profileMyApplicationsSubtitle = "profile.my_applications_subtitle"
    case profilePointsCoupons = "profile.points_coupons"
    case profilePointsCouponsSubtitle = "profile.points_coupons_subtitle"
    case profileStudentVerification = "profile.student_verification"
    case profileStudentVerificationSubtitle = "profile.student_verification_subtitle"
    case profileActivity = "profile.activity"
    case profileActivitySubtitle = "profile.activity_subtitle"
    case profileSettingsSubtitle = "profile.settings_subtitle"
    case profileWelcome = "profile.welcome"
    case profileLoginPrompt = "profile.login_prompt"
    case profileConfirmLogout = "profile.confirm_logout"
    case profileLogoutMessage = "profile.logout_message"
    
    // MARK: - Task Detail (Extended)
    case taskDetailTaskDetail = "task_detail.task_detail"
    case taskDetailShare = "task_detail.share"
    case taskDetailCancelTask = "task_detail.cancel_task"
    case taskDetailCancelTaskConfirm = "task_detail.cancel_task_confirm"
    case taskDetailNoTaskImages = "task_detail.no_task_images"
    case taskDetailVipTask = "task_detail.vip_task"
    case taskDetailSuperTask = "task_detail.super_task"
    case taskDetailTaskDescription = "task_detail.task_description"
    case taskDetailTimeInfo = "task_detail.time_info"
    case taskDetailPublishTime = "task_detail.publish_time"
    case taskDetailDeadline = "task_detail.deadline"
    case taskDetailPublisher = "task_detail.publisher"
    case taskDetailEmailNotProvided = "task_detail.email_not_provided"
    case taskDetailYourTask = "task_detail.your_task"
    case taskDetailManageTask = "task_detail.manage_task"
    case taskDetailReviews = "task_detail.reviews"
    case taskDetailMyReviews = "task_detail.my_reviews"
    case taskDetailAnonymousUser = "task_detail.anonymous_user"
    case taskDetailUnknownUser = "task_detail.unknown_user"
    case taskDetailApplyInfo = "task_detail.apply_info"
    case taskDetailPriceNegotiation = "task_detail.price_negotiation"
    case taskDetailApplyReasonHint = "task_detail.apply_reason_hint"
    case taskDetailSubmitApplication = "task_detail.submit_application"
    case taskDetailApplicantsList = "task_detail.applicants_list"
    case taskDetailNoApplicants = "task_detail.no_applicants"
    case taskDetailMessageLabel = "task_detail.message_label"
    case taskDetailWaitingReview = "task_detail.waiting_review"
    case taskDetailTaskCompleted = "task_detail.task_completed"
    case taskDetailApplicationApproved = "task_detail.application_approved"
    case taskDetailApplicationRejected = "task_detail.application_rejected"
    case taskDetailUnknownStatus = "task_detail.unknown_status"
    case taskDetailApplicationSuccess = "task_detail.application_success"
    case taskDetailApplicationSuccessMessage = "task_detail.application_success_message"
    case taskDetailTaskCompletedMessage = "task_detail.task_completed_message"
    case taskDetailConfirmCompletionSuccess = "task_detail.confirm_completion_success"
    case taskDetailConfirmCompletionSuccessMessage = "task_detail.confirm_completion_success_message"
    case taskDetailApplicationApprovedMessage = "task_detail.application_approved_message"
    case taskDetailApplicationRejectedMessage = "task_detail.application_rejected_message"
    case taskDetailPendingReview = "task_detail.pending_review"
    case taskDetailApproved = "task_detail.approved"
    case taskDetailRejected = "task_detail.rejected"
    case taskDetailUnknown = "task_detail.unknown"
    case taskDetailQualityGood = "task_detail.quality_good"
    case taskDetailOnTime = "task_detail.on_time"
    case taskDetailResponsible = "task_detail.responsible"
    case taskDetailGoodAttitude = "task_detail.good_attitude"
    case taskDetailSkilled = "task_detail.skilled"
    case taskDetailTrustworthy = "task_detail.trustworthy"
    case taskDetailRecommended = "task_detail.recommended"
    case taskDetailExcellent = "task_detail.excellent"
    case taskDetailTaskClear = "task_detail.task_clear"
    case taskDetailCommunicationTimely = "task_detail.communication_timely"
    case taskDetailPaymentTimely = "task_detail.payment_timely"
    case taskDetailReasonableRequirements = "task_detail.reasonable_requirements"
    case taskDetailPleasantCooperation = "task_detail.pleasant_cooperation"
    case taskDetailProfessionalEfficient = "task_detail.professional_efficient"
    
    // MARK: - Messages (Extended)
    case messagesLoadingMessages = "messages.loading_messages"
    case messagesNoMessagesYet = "messages.no_messages_yet"
    case messagesStartConversation = "messages.start_conversation"
    case messagesNoTaskChats = "messages.no_task_chats"
    case messagesNoTaskChatsMessage = "messages.no_task_chats_message"
    case messagesCustomerService = "messages.customer_service"
    case messagesContactService = "messages.contact_service"
    case messagesInteractionInfo = "messages.interaction_info"
    case messagesViewForumInteractions = "messages.view_forum_interactions"
    case messagesNoInteractions = "messages.no_interactions"
    case messagesNoInteractionsMessage = "messages.no_interactions_message"
    case messagesClickToView = "messages.click_to_view"
    
    // MARK: - Customer Service (Extended)
    case customerServiceWelcome = "customer_service.welcome"
    case customerServiceStartConversation = "customer_service.start_conversation"
    case customerServiceLoadingMessages = "customer_service.loading_messages"
    case customerServiceConversationEnded = "customer_service.conversation_ended"
    case customerServiceEnterMessage = "customer_service.enter_message"
    case customerServiceLoginRequired = "customer_service.login_required"
    case customerServiceWhatCanHelp = "customer_service.what_can_help"
    case customerServiceNoChatHistory = "customer_service.no_chat_history"
    case customerServiceChatHistory = "customer_service.chat_history"
    case customerServiceDone = "customer_service.done"
    case customerServiceServiceChat = "customer_service.service_chat"
    case customerServiceEnded = "customer_service.ended"
    case customerServiceInProgress = "customer_service.in_progress"
    case customerServiceSatisfactionQuestion = "customer_service.satisfaction_question"
    case customerServiceSelectRating = "customer_service.select_rating"
    case customerServiceRatingContent = "customer_service.rating_content"
    case customerServiceSubmitRating = "customer_service.submit_rating"
    case customerServiceRateServiceTitle = "customer_service.rate_service_title"
    
    // MARK: - Rating
    case ratingVeryPoor = "rating.very_poor"
    case ratingPoor = "rating.poor"
    case ratingAverage = "rating.average"
    case ratingGood = "rating.good"
    case ratingExcellent = "rating.excellent"
    case ratingRating = "rating.rating"
    case ratingSelectTags = "rating.select_tags"
    case ratingComment = "rating.comment"
    case ratingAnonymous = "rating.anonymous"
    case ratingSubmit = "rating.submit"
    
    // MARK: - Menu
    case menuMenu = "menu.menu"
    case menuMy = "menu.my"
    case menuTaskHall = "menu.task_hall"
    case menuTaskExperts = "menu.task_experts"
    case menuForum = "menu.forum"
    case menuLeaderboard = "menu.leaderboard"
    case menuFleaMarket = "menu.flea_market"
    case menuActivity = "menu.activity"
    case menuPointsCoupons = "menu.points_coupons"
    case menuStudentVerification = "menu.student_verification"
    case menuSettings = "menu.settings"
    case menuClose = "menu.close"
    
    // MARK: - Task Categories
    case taskCategoryAll = "task_category.all"
    case taskCategoryHousekeeping = "task_category.housekeeping"
    case taskCategoryCampusLife = "task_category.campus_life"
    case taskCategorySecondhandRental = "task_category.secondhand_rental"
    case taskCategoryErrandRunning = "task_category.errand_running"
    case taskCategorySkillService = "task_category.skill_service"
    case taskCategorySocialHelp = "task_category.social_help"
    case taskCategoryTransportation = "task_category.transportation"
    case taskCategoryPetCare = "task_category.pet_care"
    case taskCategoryLifeConvenience = "task_category.life_convenience"
    case taskCategoryOther = "task_category.other"
    
    // MARK: - Expert Categories
    case expertCategoryAll = "expert_category.all"
    case expertCategoryProgramming = "expert_category.programming"
    case expertCategoryTranslation = "expert_category.translation"
    case expertCategoryTutoring = "expert_category.tutoring"
    case expertCategoryFood = "expert_category.food"
    case expertCategoryBeverage = "expert_category.beverage"
    case expertCategoryCake = "expert_category.cake"
    case expertCategoryErrandTransport = "expert_category.errand_transport"
    case expertCategorySocialEntertainment = "expert_category.social_entertainment"
    case expertCategoryBeautySkincare = "expert_category.beauty_skincare"
    case expertCategoryHandicraft = "expert_category.handicraft"
    
    // MARK: - Create Task
    case createTaskBasicInfo = "create_task.basic_info"
    case createTaskRewardLocation = "create_task.reward_location"
    case createTaskCurrency = "create_task.currency"
    case createTaskTaskType = "create_task.task_type"
    case createTaskImages = "create_task.images"
    case createTaskAddImages = "create_task.add_images"
    case createTaskTitle = "create_task.title"
    case createTaskTitlePlaceholder = "create_task.title_placeholder"
    case createTaskDescription = "create_task.description"
    case createTaskDescriptionPlaceholder = "create_task.description_placeholder"
    case createTaskReward = "create_task.reward"
    case createTaskCity = "create_task.city"
    case createTaskOnline = "create_task.online"
    case createTaskCampusLifeRestriction = "create_task.campus_life_restriction"
    
    // MARK: - Task Expert
    case taskExpertBecomeExpert = "task_expert.become_expert"
    case taskExpertBecomeExpertTitle = "task_expert.become_expert_title"
    case taskExpertShowcaseSkills = "task_expert.showcase_skills"
    case taskExpertBenefits = "task_expert.benefits"
    case taskExpertHowToApply = "task_expert.how_to_apply"
    case taskExpertApplyNow = "task_expert.apply_now"
    case taskExpertLoginToApply = "task_expert.login_to_apply"
    case taskExpertApplicationInfo = "task_expert.application_info"
    case taskExpertApplicationHint = "task_expert.application_hint"
    case taskExpertSubmitApplication = "task_expert.submit_application"
    case taskExpertApplicationSubmitted = "task_expert.application_submitted"
    case taskExpertNoIntro = "task_expert.no_intro"
    case taskExpertServiceMenu = "task_expert.service_menu"
    case taskExpertOptionalTimeSlots = "task_expert.optional_time_slots"
    case taskExpertNoAvailableSlots = "task_expert.no_available_slots"
    case taskExpertApplyService = "task_expert.apply_service"
    case taskExpertOptional = "task_expert.optional"
    case taskExpertFull = "task_expert.full"
    case taskExpertApplicationMessage = "task_expert.application_message"
    case taskExpertNegotiatePrice = "task_expert.negotiate_price"
    case taskExpertExpertNegotiatePrice = "task_expert.expert_negotiate_price"
    case taskExpertViewTask = "task_expert.view_task"
    case taskExpertTaskDetails = "task_expert.task_details"
    case taskExpertClear = "task_expert.clear"
    
    // MARK: - Task Filter
    case taskFilterCategory = "task_filter.category"
    case taskFilterSelectCategory = "task_filter.select_category"
    case taskFilterCity = "task_filter.city"
    case taskFilterSelectCity = "task_filter.select_city"
    
    // MARK: - Forum
    case forumNeedLogin = "forum.need_login"
    case forumCommunityLoginMessage = "forum.community_login_message"
    case forumLoginNow = "forum.login_now"
    case forumNeedStudentVerification = "forum.need_student_verification"
    case forumVerificationPending = "forum.verification_pending"
    case forumVerificationRejected = "forum.verification_rejected"
    case forumCompleteVerification = "forum.complete_verification"
    case forumGoVerify = "forum.go_verify"
    case forumReplies = "forum.replies"
    case forumLoadRepliesFailed = "forum.load_replies_failed"
    case forumNoReplies = "forum.no_replies"
    case forumPostReply = "forum.post_reply"
    case forumSelectSection = "forum.select_section"
    case forumPleaseSelectSection = "forum.please_select_section"
    case forumPublish = "forum.publish"
    
    // MARK: - Info
    case infoConnectPlatform = "info.connect_platform"
    case infoContactUs = "info.contact_us"
    case infoMemberBenefits = "info.member_benefits"
    case infoFaq = "info.faq"
    case infoNeedHelp = "info.need_help"
    case infoContactAdmin = "info.contact_admin"
    case infoContactService = "info.contact_service"
    case infoTermsOfService = "info.terms_of_service"
    case infoPrivacyPolicy = "info.privacy_policy"
    case infoLastUpdated = "info.last_updated"
    
    // MARK: - Flea Market Additional
    case fleaMarketNoImage = "flea_market.no_image"
    case fleaMarketProductInfo = "flea_market.product_info"
    case fleaMarketProductTitle = "flea_market.product_title"
    case fleaMarketProductTitlePlaceholder = "flea_market.product_title_placeholder"
    case fleaMarketCategory = "flea_market.category"
    case fleaMarketDescription = "flea_market.description"
    case fleaMarketDescriptionPlaceholder = "flea_market.description_placeholder"
    case fleaMarketPriceAndTransaction = "flea_market.price_and_transaction"
    case fleaMarketPrice = "flea_market.price"
    case fleaMarketContact = "flea_market.contact"
    case fleaMarketContactPlaceholder = "flea_market.contact_placeholder"
    case fleaMarketProductImages = "flea_market.product_images"
    case fleaMarketAddImage = "flea_market.add_image"
    case fleaMarketTransactionLocation = "flea_market.transaction_location"
    case fleaMarketOnline = "flea_market.online"
    
    // MARK: - My Tasks Additional
    case myTasksPending = "my_tasks.pending"
    case myTasksApplicationMessage = "my_tasks.application_message"
    case myTasksViewDetails = "my_tasks.view_details"
    
    // MARK: - Task Location
    case taskLocationAddress = "task_location.address"
    case taskLocationCoordinates = "task_location.coordinates"
    case taskLocationAppleMaps = "task_location.apple_maps"
    case taskLocationMyLocation = "task_location.my_location"
    case taskLocationLoadingAddress = "task_location.loading_address"
    case taskLocationDetailAddress = "task_location.detail_address"
    
    // MARK: - Flea Market Additional
    case fleaMarketPublishItem = "flea_market.publish_item"
    case fleaMarketConfirmPurchase = "flea_market.confirm_purchase"
    case fleaMarketBidPurchase = "flea_market.bid_purchase"
    case fleaMarketAutoRemovalDays = "flea_market.auto_removal_days"
    case fleaMarketAutoRemovalSoon = "flea_market.auto_removal_soon"
    case fleaMarketLoading = "flea_market.loading"
    case fleaMarketLoadFailed = "flea_market.load_failed"
    case fleaMarketProductDetail = "flea_market.product_detail"
    case fleaMarketNoDescription = "flea_market.no_description"
    case fleaMarketActiveSeller = "flea_market.active_seller"
    case fleaMarketContactSeller = "flea_market.contact_seller"
    case fleaMarketEditItem = "flea_market.edit_item"
    case fleaMarketFavorite = "flea_market.favorite"
    case fleaMarketNegotiate = "flea_market.negotiate"
    case fleaMarketBuyNow = "flea_market.buy_now"
    case fleaMarketYourBid = "flea_market.your_bid"
    case fleaMarketMessageToSeller = "flea_market.message_to_seller"
    case fleaMarketMessagePlaceholder = "flea_market.message_placeholder"
    case fleaMarketEnterAmount = "flea_market.enter_amount"
    
    // MARK: - Task Preferences
    case taskPreferencesTitle = "task_preferences.title"
    case taskPreferencesPreferredTypes = "task_preferences.preferred_types"
    case taskPreferencesPreferredTypesDescription = "task_preferences.preferred_types_description"
    case taskPreferencesPreferredLocations = "task_preferences.preferred_locations"
    case taskPreferencesPreferredLocationsDescription = "task_preferences.preferred_locations_description"
    case taskPreferencesPreferredLevels = "task_preferences.preferred_levels"
    case taskPreferencesPreferredLevelsDescription = "task_preferences.preferred_levels_description"
    case taskPreferencesMinDeadline = "task_preferences.min_deadline"
    case taskPreferencesMinDeadlineDescription = "task_preferences.min_deadline_description"
    case taskPreferencesDays = "task_preferences.days"
    case taskPreferencesDaysRange = "task_preferences.days_range"
    case taskPreferencesSave = "task_preferences.save"
    case taskLocationSearchCity = "task_location.search_city"
    
    // MARK: - Forum Create Post
    case forumCreatePostTitle = "forum.create_post_title"
    case forumCreatePostBasicInfo = "forum.create_post_basic_info"
    case forumCreatePostPostTitle = "forum.create_post_post_title"
    case forumCreatePostPostTitlePlaceholder = "forum.create_post_post_title_placeholder"
    case forumCreatePostPostContent = "forum.create_post_post_content"
    case forumCreatePostContentPlaceholder = "forum.create_post_content_placeholder"
    case forumCreatePostPublishing = "forum.create_post_publishing"
    case forumCreatePostPublishNow = "forum.create_post_publish_now"
    
    // MARK: - Flea Market Create
    case fleaMarketCreatePublishing = "flea_market.create_publishing"
    case fleaMarketCreatePublishNow = "flea_market.create_publish_now"
    case fleaMarketCreateSearchLocation = "flea_market.create_search_location"
    
    // MARK: - Task Expert
    case taskExpertTitle = "task_expert.title"
    case taskExpertWhatIs = "task_expert.what_is"
    case taskExpertWhatIsContent = "task_expert.what_is_content"
    case taskExpertBenefits = "task_expert.benefits"
    case taskExpertMoreExposure = "task_expert.more_exposure"
    case taskExpertMoreExposureDesc = "task_expert.more_exposure_desc"
    case taskExpertExclusiveBadge = "task_expert.exclusive_badge"
    case taskExpertExclusiveBadgeDesc = "task_expert.exclusive_badge_desc"
    case taskExpertMoreOrders = "task_expert.more_orders"
    case taskExpertMoreOrdersDesc = "task_expert.more_orders_desc"
    case taskExpertPlatformSupport = "task_expert.platform_support"
    case taskExpertPlatformSupportDesc = "task_expert.platform_support_desc"
    case taskExpertHowToApply = "task_expert.how_to_apply"
    case taskExpertFillApplication = "task_expert.fill_application"
    case taskExpertFillApplicationDesc = "task_expert.fill_application_desc"
    case taskExpertSubmitReview = "task_expert.submit_review"
    case taskExpertSubmitReviewDesc = "task_expert.submit_review_desc"
    case taskExpertStartService = "task_expert.start_service"
    case taskExpertStartServiceDesc = "task_expert.start_service_desc"
    case taskExpertApplyNow = "task_expert.apply_now"
    case taskExpertLoginToApply = "task_expert.login_to_apply"
    case taskExpertBecomeExpert = "task_expert.become_expert"
    case taskExpertApplyTitle = "task_expert.apply_title"
    case taskExpertApplicationInfo = "task_expert.application_info"
    case taskExpertApplicationSubmitted = "task_expert.application_submitted"
    case taskExpertApplicationSubmittedMessage = "task_expert.application_submitted_message"
    case taskExpertNoExperts = "task_expert.no_experts"
    case taskExpertNoExpertsMessage = "task_expert.no_experts_message"
    case taskExpertNoExpertsSearchMessage = "task_expert.no_experts_search_message"
    case taskExpertSearchPrompt = "task_expert.search_prompt"
    case taskExpertClear = "task_expert.clear"
    case taskExpertNoFavorites = "task_expert.no_favorites"
    case taskExpertNoActivities = "task_expert.no_activities"
    case taskExpertNoFavoritesMessage = "task_expert.no_favorites_message"
    case taskExpertNoAppliedMessage = "task_expert.no_applied_message"
    case taskExpertNoActivitiesMessage = "task_expert.no_activities_message"
    
    // MARK: - Leaderboard
    case leaderboardApplyTitle = "leaderboard.apply_title"
    case leaderboardInfo = "leaderboard.info"
    case leaderboardName = "leaderboard.name"
    case leaderboardNamePlaceholder = "leaderboard.name_placeholder"
    case leaderboardRegion = "leaderboard.region"
    case leaderboardDescription = "leaderboard.description"
    case leaderboardDescriptionPlaceholder = "leaderboard.description_placeholder"
    case leaderboardReason = "leaderboard.reason"
    case leaderboardReasonTitle = "leaderboard.reason_title"
    case leaderboardReasonPlaceholder = "leaderboard.reason_placeholder"
    case leaderboardCoverImage = "leaderboard.cover_image"
    case leaderboardAddCoverImage = "leaderboard.add_cover_image"
    case leaderboardLoading = "leaderboard.loading"
    
    // MARK: - Notification
    case notificationNoTaskChat = "notification.no_task_chat"
    case notificationPoster = "notification.poster"
    case notificationTaker = "notification.taker"
    case notificationExpert = "notification.expert"
    case notificationParticipant = "notification.participant"
    case notificationSystem = "notification.system"
    case notificationSystemMessage = "notification.system_message"
    case notificationNoMessages = "notification.no_messages"
    case notificationStartConversation = "notification.start_conversation"
    case notificationViewDetails = "notification.view_details"
    case notificationImage = "notification.image"
    case notificationTaskDetail = "notification.task_detail"
    case notificationDetailAddress = "notification.detail_address"
    case notificationNotifications = "notification.notifications"
    case notificationNoTaskChatMessage = "notification.no_task_chat_message"
    case notificationTaskEnded = "notification.task_ended"
    case notificationTaskCompletedCannotSend = "notification.task_completed_cannot_send"
    case notificationTaskCancelledCannotSend = "notification.task_cancelled_cannot_send"
    case notificationTaskPendingCannotSend = "notification.task_pending_cannot_send"
    case notificationCustomerService = "notification.customer_service"
    case notificationContactService = "notification.contact_service"
    case notificationTaskChat = "notification.task_chat"
    case notificationTaskChatList = "notification.task_chat_list"
    
    /// 获取本地化字符串
    public var localized: String {
        return LocalizationHelper.localized(self.rawValue)
    }
    
    /// 获取本地化字符串（带参数）
    public func localized(_ arguments: CVarArg...) -> String {
        return LocalizationHelper.localized(self.rawValue, arguments: arguments)
    }
    
    /// 获取本地化字符串（带单个参数）
    public func localized(argument: CVarArg) -> String {
        return LocalizationHelper.localized(self.rawValue, argument: argument)
    }
}

