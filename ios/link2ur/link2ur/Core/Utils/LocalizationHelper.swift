import Foundation

/// 本地化辅助工具 - 企业级多语言支持
public struct LocalizationHelper {
    
    /// 当前语言代码
    public static var currentLanguage: String {
        if #available(iOS 16, *) {
            return Locale.current.language.languageCode?.identifier ?? "en"
        } else {
            return Locale.current.languageCode ?? "en"
        }
    }
    
    /// 当前区域代码
    public static var currentRegion: String {
        if #available(iOS 16, *) {
            return Locale.current.region?.identifier ?? "US"
        } else {
            return Locale.current.regionCode ?? "US"
        }
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
    
    // MARK: - App
    case appName = "app.name"
    case appTagline = "app.tagline"
    case appUser = "app.user"
    
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
    
    // MARK: - Flea Market
    case fleaMarketFleaMarket = "flea_market.flea_market"
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
    
    // MARK: - Notifications
    case notificationsNotifications = "notifications.notifications"
    case notificationsNoNotifications = "notifications.no_notifications"
    case notificationsMarkAllRead = "notifications.mark_all_read"
    
    // MARK: - Student Verification
    case studentVerificationVerification = "student_verification.verification"
    case studentVerificationSubmit = "student_verification.submit"
    case studentVerificationUploadDocument = "student_verification.upload_document"
    
    // MARK: - Customer Service
    case customerServiceCustomerService = "customer_service.customer_service"
    case customerServiceChatWithService = "customer_service.chat_with_service"
    
    // MARK: - Activity
    case activityActivity = "activity.activity"
    case activityRecentActivity = "activity.recent_activity"
    
    // MARK: - Search
    case searchSearch = "search.search"
    case searchResults = "search.results"
    case searchNoResults = "search.no_results"
    case searchTryOtherKeywords = "search.try_other_keywords"
    
    // MARK: - Errors
    case errorNetworkError = "error.network_error"
    case errorUnknownError = "error.unknown_error"
    case errorInvalidInput = "error.invalid_input"
    case errorLoginFailed = "error.login_failed"
    case errorRegisterFailed = "error.register_failed"
    
    // MARK: - Success
    case successOperationSuccess = "success.operation_success"
    case successSaved = "success.saved"
    case successDeleted = "success.deleted"
    
    // MARK: - Currency
    case currencyPound = "currency.pound"
    case currencyPoints = "currency.points"
    
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
    case customerServiceQueuePosition = "customer_service.queue_position"
    case customerServiceEstimatedWait = "customer_service.estimated_wait"
    case customerServiceConversationEnded = "customer_service.conversation_ended"
    case customerServiceNewConversation = "customer_service.new_conversation"
    case customerServiceEnterMessage = "customer_service.enter_message"
    case customerServiceConnecting = "customer_service.connecting"
    case customerServiceEndConversation = "customer_service.end_conversation"
    case customerServiceHistory = "customer_service.history"
    case customerServiceLoginRequired = "customer_service.login_required"
    case customerServiceWhatCanHelp = "customer_service.what_can_help"
    case customerServiceNoChatHistory = "customer_service.no_chat_history"
    case customerServiceStartNewConversation = "customer_service.start_new_conversation"
    case customerServiceChatHistory = "customer_service.chat_history"
    case customerServiceDone = "customer_service.done"
    case customerServiceServiceChat = "customer_service.service_chat"
    case customerServiceEnded = "customer_service.ended"
    case customerServiceInProgress = "customer_service.in_progress"
    case customerServiceRateService = "customer_service.rate_service"
    case customerServiceSatisfactionQuestion = "customer_service.satisfaction_question"
    case customerServiceSelectRating = "customer_service.select_rating"
    case customerServiceRatingContent = "customer_service.rating_content"
    case customerServiceSubmitRating = "customer_service.submit_rating"
    case customerServiceRateServiceTitle = "customer_service.rate_service_title"
    case customerServiceSkip = "customer_service.skip"
    
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
    
    // MARK: - Forum
    case forumNeedLogin = "forum.need_login"
    case forumCommunityLoginMessage = "forum.community_login_message"
    case forumLoginNow = "forum.login_now"
    case forumNeedStudentVerification = "forum.need_student_verification"
    case forumVerificationPending = "forum.verification_pending"
    case forumVerificationRejected = "forum.verification_rejected"
    case forumCompleteVerification = "forum.complete_verification"
    case forumGoVerify = "forum.go_verify"
    case forumOfficial = "forum.official"
    case forumReplies = "forum.replies"
    case forumLoadRepliesFailed = "forum.load_replies_failed"
    case forumNoReplies = "forum.no_replies"
    case forumReply = "forum.reply"
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

