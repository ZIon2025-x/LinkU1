// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get commonOk => 'OK';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonGoSetup => 'Go to setup';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonSave => 'Save';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonClose => 'Close';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonReport => 'Report';

  @override
  String get commonReportReason => 'Please enter the reason for reporting';

  @override
  String get commonReportSubmitted => 'Report submitted';

  @override
  String get commonCopyLink => 'Copy Link';

  @override
  String get commonLinkCopied => 'Link copied';

  @override
  String get commonReload => 'Reload';

  @override
  String get commonLoading => 'Loading...';

  @override
  String get commonSearch => 'Search';

  @override
  String get commonClear => 'Clear';

  @override
  String get commonSubmit => 'Submit';

  @override
  String get commonSubmitting => 'Submitting...';

  @override
  String get commonBack => 'Back';

  @override
  String get commonNext => 'Next';

  @override
  String get commonFinish => 'Finish';

  @override
  String get commonDone => 'Done';

  @override
  String get commonNotice => 'Notice';

  @override
  String get commonShare => 'Share';

  @override
  String get commonMore => 'More';

  @override
  String get commonViewAll => 'View All';

  @override
  String get commonLoadingImage => 'Loading image...';

  @override
  String get commonAll => 'All';

  @override
  String get commonFilter => 'Filter';

  @override
  String get commonReset => 'Reset';

  @override
  String get commonNotProvided => 'Not provided';

  @override
  String get commonPleaseSelect => 'Please select';

  @override
  String get commonUser => 'User';

  @override
  String commonUserWithId(String id) {
    return 'User $id';
  }

  @override
  String taskExpertWithId(String id) {
    return 'Expert $id';
  }

  @override
  String get appName => 'Link²Ur';

  @override
  String get appTagline => 'Connect you and me, create value';

  @override
  String get appUser => 'Link²Ur User';

  @override
  String get appTermsOfService => 'Terms of Service';

  @override
  String get appPrivacyPolicy => 'Privacy Policy';

  @override
  String get appAbout => 'About';

  @override
  String get appVersion => 'Version';

  @override
  String get authLogin => 'Login';

  @override
  String get authRegister => 'Register';

  @override
  String get authLogout => 'Logout';

  @override
  String get authSessionExpired =>
      'Your session has expired, please log in again';

  @override
  String get authForgotPassword => 'Forgot Password';

  @override
  String get authEmail => 'Email';

  @override
  String get authEmailOrId => 'Email/ID';

  @override
  String get authPassword => 'Password';

  @override
  String get authPhone => 'Phone';

  @override
  String get authVerificationCode => 'Verification Code';

  @override
  String get authLoginLater => 'Login Later';

  @override
  String authCountdownSeconds(int param1) {
    return '$param1 seconds';
  }

  @override
  String get loginRequired => 'Login Required';

  @override
  String get loginRequiredForPoints =>
      'Please login to view points and coupons';

  @override
  String get loginRequiredForVerification =>
      'Please login to verify student status';

  @override
  String get loginLoginNow => 'Login Now';

  @override
  String get authSendCode => 'Send Code';

  @override
  String get authResendCode => 'Resend Code';

  @override
  String get authLoginMethod => 'Login Method';

  @override
  String get authEmailPassword => 'Email/ID & Password';

  @override
  String get authEmailCode => 'Email Code';

  @override
  String get authPhoneCode => 'Phone Verification';

  @override
  String get authEnterEmail => 'Enter email';

  @override
  String get authEnterEmailOrId => 'Enter email or ID';

  @override
  String get authEnterPassword => 'Enter password';

  @override
  String get authEnterPhone => 'Enter phone number';

  @override
  String get authEnterCode => 'Enter verification code';

  @override
  String get authNoAccount => 'Don\'t have an account?';

  @override
  String get authHasAccount => 'Already have an account?';

  @override
  String get authRegisterNow => 'Register Now';

  @override
  String get authLoginNow => 'Login Now';

  @override
  String get authNoAccountUseCode => 'Login with verification code';

  @override
  String get authRegisterSuccess => 'Registration Successful';

  @override
  String get authCaptchaTitle => 'Verification';

  @override
  String get authCaptchaMessage => 'Please complete the verification';

  @override
  String get authCaptchaError =>
      'Unable to load verification, please try again later';

  @override
  String get authUsername => 'Username';

  @override
  String get authEnterUsername => 'Enter username';

  @override
  String get authPasswordHint =>
      'At least 8 characters, including letters and numbers';

  @override
  String get authPhoneOptional => 'Phone (Optional)';

  @override
  String get authInvitationCodeOptional =>
      'Invite Code / Inviter ID (Optional)';

  @override
  String get authInvitationCodeHint => 'Enter invite code or 8-digit user ID';

  @override
  String get authAgreeToTerms => 'I have read and agree to the';

  @override
  String get authTermsOfService => 'Terms of Service';

  @override
  String get authPrivacyPolicy => 'Privacy Policy';

  @override
  String get homeExperts => 'Experts';

  @override
  String get homeRecommended => 'Link²Ur';

  @override
  String get homeNearby => 'Nearby';

  @override
  String homeGreeting(String param1) {
    return 'Hello, $param1';
  }

  @override
  String get homeWhatToDo => 'What would you like to do today?';

  @override
  String get homeMenu => 'Menu';

  @override
  String get homeSearchExperts => 'Search Experts';

  @override
  String get homeSearch => 'Search';

  @override
  String get homeNoResults => 'No results found';

  @override
  String get homeTryOtherKeywords => 'Try other keywords';

  @override
  String get homeSearchHistory => 'Search History';

  @override
  String get homeHotSearches => 'Hot Searches';

  @override
  String get homeNoNearbyTasks => 'No nearby tasks';

  @override
  String get homeNoNearbyTasksMessage =>
      'No tasks have been posted nearby yet. Be the first to post one!';

  @override
  String get homeNoExperts => 'No task experts';

  @override
  String get homeNoExpertsMessage => 'No task experts yet, stay tuned...';

  @override
  String get homeRecommendedTasks => 'Recommended Tasks';

  @override
  String get homeRecommendedBadge => 'Pick';

  @override
  String get homeMemberPublished => 'Member Published';

  @override
  String get homeMemberSeller => 'Member Seller';

  @override
  String get homeNoRecommendedTasks => 'No recommended tasks';

  @override
  String get homeNoRecommendedTasksMessage =>
      'No recommended tasks yet. Check out the task hall!';

  @override
  String get homeLatestActivity => 'Latest Activity';

  @override
  String get homeNoActivity => 'No activity';

  @override
  String get homeNoActivityMessage => 'No latest activity yet';

  @override
  String get homeNoMoreActivity => 'Above are the latest activities';

  @override
  String get homeLoadMore => 'Load More';

  @override
  String get homeHotEvents => 'Hot Events';

  @override
  String get homeNoEvents => 'No events';

  @override
  String get homeNoEventsMessage => 'No events at the moment, stay tuned...';

  @override
  String get homeViewEvent => 'View Event';

  @override
  String get homeTapToViewEvents => 'Tap to view latest events';

  @override
  String get homeMultiplePeople => 'Multiple People';

  @override
  String get homeView => 'View';

  @override
  String get tasksTaskDetail => 'Task Details';

  @override
  String get tasksLoadFailed => 'Failed to load';

  @override
  String get tasksCancelTask => 'Cancel Task';

  @override
  String get tasksCancelTaskConfirm =>
      'Are you sure you want to cancel this task?';

  @override
  String get tasksApply => 'Apply';

  @override
  String get tasksApplyTask => 'Apply for Task';

  @override
  String get tasksApplyMessage => 'Message (Optional)';

  @override
  String get tasksApplyInfo => 'Application Info';

  @override
  String get tasksPriceNegotiation => 'Price Negotiation';

  @override
  String get tasksApplyHint =>
      'Explain your application reason to the publisher to improve success rate';

  @override
  String get tasksSubmitApplication => 'Submit Application';

  @override
  String get tasksNoApplicants => 'No applicants';

  @override
  String tasksApplicantsList(int param1) {
    return 'Applicants List ($param1)';
  }

  @override
  String tasksMessageLabel(String param1) {
    return 'Message: $param1';
  }

  @override
  String get tasksTaskDescription => 'Task Description';

  @override
  String get tasksTimeInfo => 'Time Information';

  @override
  String get tasksPublishTime => 'Publish Time';

  @override
  String get tasksDeadline => 'Deadline';

  @override
  String get tasksPublisher => 'Publisher';

  @override
  String get tasksYourTask => 'This is your task';

  @override
  String get tasksManageTask =>
      'You can view applicants and manage the task below';

  @override
  String tasksReviews(int param1) {
    return 'Reviews ($param1)';
  }

  @override
  String get tasksNoTaskImages => 'No task images';

  @override
  String tasksPointsReward(int param1) {
    return '$param1 Points';
  }

  @override
  String get tasksShareTo => 'Share to...';

  @override
  String get tasksTask => 'Task';

  @override
  String get tasksTasks => 'Tasks';

  @override
  String get tasksNotInterested => 'Not Interested';

  @override
  String get tasksMarkNotInterestedConfirm =>
      'Are you sure you want to mark this task as not interested?';

  @override
  String get tasksMyTasks => 'My Tasks';

  @override
  String get expertsExperts => 'Task Experts';

  @override
  String get expertsBecomeExpert => 'Become an Expert';

  @override
  String get expertsSearchExperts => 'Search Task Experts';

  @override
  String get expertsApplyNow => 'Apply Now';

  @override
  String get expertsLoginToApply => 'Login to Apply';

  @override
  String get forumForum => 'Forum';

  @override
  String get forumAllPosts => 'All Posts';

  @override
  String get forumNoPosts => 'No Posts';

  @override
  String get forumNoPostsMessage =>
      'There are no posts yet. Be the first to post!';

  @override
  String get forumSearchPosts => 'Search posts...';

  @override
  String get forumPosts => 'Posts';

  @override
  String get forumPostLoadFailed => 'Failed to load post';

  @override
  String get forumOfficial => 'Official';

  @override
  String get forumAllReplies => 'All Comments';

  @override
  String get forumReply => 'Reply';

  @override
  String get forumReplyTo => 'Reply to';

  @override
  String get forumWriteReply => 'Write your reply...';

  @override
  String get forumSend => 'Send';

  @override
  String get forumView => 'Views';

  @override
  String get forumLike => 'Likes';

  @override
  String get forumFavorite => 'Favorites';

  @override
  String get fleaMarketFleaMarket => 'Flea Market';

  @override
  String get fleaMarketSubtitle =>
      'Discover great items, sell your unused goods';

  @override
  String get fleaMarketNoItems => 'No items';

  @override
  String get fleaMarketNoItemsMessage =>
      'The flea market has no items yet. Be the first to post one!';

  @override
  String get fleaMarketSearchItems => 'Search items';

  @override
  String get fleaMarketItems => 'Items';

  @override
  String get fleaMarketCategory => 'Product Category';

  @override
  String get fleaMarketProductImages => 'Product Images';

  @override
  String get fleaMarketAddImage => 'Add Image';

  @override
  String get fleaMarketProductInfo => 'Product Information';

  @override
  String get fleaMarketProductTitle => 'Product Title';

  @override
  String get fleaMarketProductTitlePlaceholder => 'Enter product title';

  @override
  String get fleaMarketDescription => 'Description';

  @override
  String get fleaMarketDescriptionPlaceholder =>
      'Describe your product in detail';

  @override
  String get fleaMarketPrice => 'Price';

  @override
  String get fleaMarketContact => 'Contact';

  @override
  String get fleaMarketContactPlaceholder => 'Enter contact information';

  @override
  String get fleaMarketNoImage => 'No Image';

  @override
  String get fleaMarketTransactionLocation => 'Transaction Location';

  @override
  String get fleaMarketOnline => 'Online';

  @override
  String get profileProfile => 'Profile';

  @override
  String get profileMyTasks => 'My Tasks';

  @override
  String get profileMyPosts => 'My Items';

  @override
  String get profileSettings => 'Settings';

  @override
  String get profileAbout => 'About';

  @override
  String get profileLogout => 'Logout';

  @override
  String get profileLogoutConfirm => 'Are you sure you want to logout?';

  @override
  String get profilePleaseUpdateEmailTitle => 'Please Update Email';

  @override
  String get profilePleaseUpdateEmailMessage =>
      'Please update your email address in Settings to avoid missing important notifications.';

  @override
  String get profileName => 'Name';

  @override
  String get profileEnterName => 'Enter name';

  @override
  String get profileEmail => 'Email';

  @override
  String get profileEnterEmail => 'Enter email';

  @override
  String get profileEnterNewEmail => 'Enter new email';

  @override
  String get profileVerificationCode => 'Verification Code';

  @override
  String get profileEnterVerificationCode => 'Enter verification code';

  @override
  String get profilePhone => 'Phone';

  @override
  String get profileEnterPhone => 'Enter phone number';

  @override
  String get profileEnterNewPhone => 'Enter new phone number';

  @override
  String get profileClickToChangeAvatar => 'Tap camera icon to change avatar';

  @override
  String get profileEditProfile => 'Edit Profile';

  @override
  String get profileUpdated => 'Profile Updated';

  @override
  String get messagesMessages => 'Messages';

  @override
  String get messagesChat => 'Chat';

  @override
  String get messagesSend => 'Send';

  @override
  String get messagesEnterMessage => 'Enter message...';

  @override
  String get leaderboardLeaderboard => 'Leaderboard';

  @override
  String get leaderboardRank => 'Rank';

  @override
  String get leaderboardPoints => 'Points';

  @override
  String get leaderboardUser => 'User';

  @override
  String get leaderboardLoadFailed => 'Failed to load leaderboard';

  @override
  String get leaderboardSortComprehensive => 'Comprehensive';

  @override
  String get leaderboardSortNetVotes => 'Net Votes';

  @override
  String get leaderboardSortUpvotes => 'Upvotes';

  @override
  String get leaderboardSortLatest => 'Latest';

  @override
  String get leaderboardNoItems => 'No Leaderboards';

  @override
  String get leaderboardNoItemsMessage =>
      'This leaderboard has no participants yet. Be the first to submit!';

  @override
  String get leaderboardItemCount => 'Entries';

  @override
  String get leaderboardTotalVotes => 'Total Votes';

  @override
  String get leaderboardViewCount => 'Views';

  @override
  String get leaderboardItemLoadFailed => 'Failed to load item';

  @override
  String leaderboardSubmittedBy(String param1) {
    return 'Submitted by $param1';
  }

  @override
  String get leaderboardItemDetail => 'Item Detail';

  @override
  String get leaderboardNoDescription => 'No description available';

  @override
  String get leaderboardContactLocation => 'Contact & Location';

  @override
  String get leaderboardCurrentScore => 'Current Score';

  @override
  String get leaderboardTotalVotesCount => 'Total Votes';

  @override
  String get leaderboardFeaturedComments => 'Featured Comments';

  @override
  String get leaderboardNoComments => 'No comments yet, share your thoughts!';

  @override
  String get leaderboardOppose => 'Oppose';

  @override
  String get leaderboardSupport => 'Support';

  @override
  String get leaderboardNoImages => 'No Images';

  @override
  String get leaderboardWriteReason =>
      'Write your reason for others to reference...';

  @override
  String get leaderboardAnonymousVote => 'Anonymous Vote';

  @override
  String get leaderboardSubmitVote => 'Submit Vote';

  @override
  String get leaderboardAddImage => 'Add Image';

  @override
  String get leaderboardApplyNew => 'Apply for New Leaderboard';

  @override
  String get leaderboardSupportReason => 'Support Reason';

  @override
  String get leaderboardOpposeReason => 'Oppose Reason';

  @override
  String get leaderboardAnonymousUser => 'Anonymous User';

  @override
  String get leaderboardConfirmSupport => 'Confirm Support';

  @override
  String get leaderboardConfirmOppose => 'Confirm Oppose';

  @override
  String get leaderboardCopied => 'Copied to clipboard';

  @override
  String get leaderboardComments => 'Vote Comments';

  @override
  String get leaderboardContactInfoDetail => 'Contact Info';

  @override
  String get leaderboardNetScore => 'Net Score';

  @override
  String get leaderboardBasicInfo => 'Basic Information';

  @override
  String get leaderboardContactInfo => 'Contact Information (Optional)';

  @override
  String get leaderboardImageDisplay => 'Image Display (Optional)';

  @override
  String get leaderboardItemName => 'Name';

  @override
  String get leaderboardItemDescription => 'Description';

  @override
  String get leaderboardItemAddress => 'Address';

  @override
  String get leaderboardItemPhone => 'Phone';

  @override
  String get leaderboardItemWebsite => 'Official Website';

  @override
  String get leaderboardSubmitItem => 'Submit Entry';

  @override
  String get leaderboardSubmitting => 'Submitting...';

  @override
  String get leaderboardNamePlaceholder =>
      'e.g., Most Popular Chinese Restaurant';

  @override
  String get leaderboardDescriptionPlaceholder =>
      'Please describe the purpose and inclusion criteria of this leaderboard...';

  @override
  String get leaderboardAddressPlaceholder => 'Please enter detailed address';

  @override
  String get leaderboardPhonePlaceholder => 'Please enter phone number';

  @override
  String get leaderboardWebsitePlaceholder => 'Please enter website address';

  @override
  String get leaderboardPleaseEnterItemName => 'Please enter item name';

  @override
  String get activityPerson => 'person';

  @override
  String get activityPersonsBooked => 'persons booked';

  @override
  String taskExpertServicesCount(int param1) {
    return '$param1 services';
  }

  @override
  String get taskExpertCompletionRate => 'Completion Rate';

  @override
  String get taskExpertNoServices => 'No Services';

  @override
  String get taskExpertOrder => 'order';

  @override
  String taskExpertCompletionRatePercent(int param1) {
    return '$param1% Completion Rate';
  }

  @override
  String get taskExpertSearchExperts => 'Search Task Experts';

  @override
  String get taskExpertNoExpertsFound => 'No experts found';

  @override
  String get taskExpertNoExpertsFoundMessage =>
      'Try adjusting filter conditions';

  @override
  String get taskExpertNoExpertsFoundWithQuery =>
      'No experts found matching your search';

  @override
  String get taskExpertSearchTitle => 'Search experts';

  @override
  String get taskExpertAllTypes => 'All Types';

  @override
  String get taskExpertType => 'Type';

  @override
  String get taskExpertLocation => 'Location';

  @override
  String get taskExpertAllCities => 'All Cities';

  @override
  String get taskExpertRating => 'Rating';

  @override
  String get taskExpertCompleted => 'Completed';

  @override
  String get serviceLoading => 'Loading...';

  @override
  String get serviceLoadFailed => 'Failed to load service information';

  @override
  String get serviceNeedDescription =>
      'Briefly describe your needs to help the expert understand...';

  @override
  String get locationGoogleMaps => 'Google Maps';

  @override
  String get webviewWebPage => 'Web Page';

  @override
  String get webviewLoading => 'Loading...';

  @override
  String get webviewDone => 'Done';

  @override
  String get profileRecentTasks => 'Recent Tasks';

  @override
  String get profileUserReviews => 'User Reviews';

  @override
  String profileJoinedDays(int param1) {
    return 'Joined $param1 days ago';
  }

  @override
  String get profileReward => 'Reward';

  @override
  String get profileSelectAvatar => 'Select Avatar';

  @override
  String get locationTitle => 'Location';

  @override
  String get locationSearchPlaceholder => 'Search location or enter Online';

  @override
  String get locationGettingAddress => 'Getting address...';

  @override
  String get locationDragToSelect => 'Drag map to select location';

  @override
  String get locationCurrentLocation => 'Current Location';

  @override
  String get locationOnlineRemote => 'Online/Remote';

  @override
  String get locationSelectTitle => 'Select location';

  @override
  String get locationSearchPlace => 'Search place, address, postcode...';

  @override
  String get locationMoving => 'Moving';

  @override
  String get searchResultsTitle => 'Search results';

  @override
  String get taskExpertLoading => 'Loading...';

  @override
  String get taskExpertLoadFailed => 'Failed to load expert info';

  @override
  String get externalWebLoading => 'Loading...';

  @override
  String get emptyStateNoContent => 'No content yet';

  @override
  String get emptyStateNoContentMessage =>
      'Nothing here yet. Try refreshing or come back later.';

  @override
  String get emptyStateNoResults => 'No results found';

  @override
  String get emptyStateNoResultsMessage =>
      'No matching search results. Try other keywords.';

  @override
  String get leaderboardEmptyTitle => 'No leaderboard yet';

  @override
  String get leaderboardEmptyMessage => 'Be the first to create one!';

  @override
  String get leaderboardSortHot => 'Hot';

  @override
  String get leaderboardSortVotes => 'Votes';

  @override
  String get leaderboardAddItem => 'Add item';

  @override
  String get leaderboardVoteCount => 'Votes';

  @override
  String get paymentSetupAccount => 'Setup Payment Account';

  @override
  String get paymentPleaseSetupFirst => 'Please set up payment account first';

  @override
  String get paymentPleaseSetupMessage =>
      'You need to set up your payment account before applying for tasks. Please go to Settings to complete setup.';

  @override
  String get notificationsNotifications => 'Notifications';

  @override
  String get notificationsNoNotifications => 'No notifications';

  @override
  String get notificationsMarkAllRead => 'Mark All as Read';

  @override
  String get notificationAgree => 'Agree';

  @override
  String get notificationReject => 'Reject';

  @override
  String get notificationExpired => 'Expired';

  @override
  String get notificationNoNotifications => 'No Notifications';

  @override
  String get notificationNoNotificationsMessage =>
      'No notification messages received yet';

  @override
  String get notificationEnableNotification => 'Enable Notifications';

  @override
  String get notificationEnableNotificationTitle => 'Enable Notifications';

  @override
  String get notificationEnableNotificationMessage =>
      'Receive task updates and message reminders in time';

  @override
  String get notificationEnableNotificationDescription =>
      'Don\'t miss any important information';

  @override
  String get notificationAllowNotification => 'Allow Notifications';

  @override
  String get notificationNotNow => 'Not Now';

  @override
  String get studentVerificationVerification => 'Student Verification';

  @override
  String get studentVerificationSubmit => 'Submit Verification';

  @override
  String get studentVerificationUploadDocument => 'Upload Document';

  @override
  String get studentVerificationEmailInfo => 'Email Information';

  @override
  String get studentVerificationSchoolEmail => 'School Email';

  @override
  String get studentVerificationSchoolEmailPlaceholder =>
      'Enter your .ac.uk or .edu email';

  @override
  String get studentVerificationRenewVerification => 'Renew Verification';

  @override
  String get studentVerificationChangeEmail => 'Change Email';

  @override
  String get studentVerificationSubmitVerification => 'Submit Verification';

  @override
  String get studentVerificationStudentVerificationTitle =>
      'Student Verification';

  @override
  String get studentVerificationDescription =>
      'Verify your student identity to enjoy student-exclusive benefits';

  @override
  String get studentVerificationStartVerification => 'Start Verification';

  @override
  String studentVerificationStatus(String param1) {
    return 'Status: $param1';
  }

  @override
  String get studentVerificationEmailInstruction =>
      'Note: Please enter your school email address, and we will send a verification email to that address.';

  @override
  String get studentVerificationRenewInfo => 'Renewal Information';

  @override
  String get studentVerificationRenewEmailPlaceholder =>
      'Enter your school email';

  @override
  String get studentVerificationRenewInstruction =>
      'Note: Please enter your school email address to renew verification.';

  @override
  String get studentVerificationNewSchoolEmail => 'New School Email';

  @override
  String get studentVerificationNewSchoolEmailPlaceholder =>
      'Enter new school email';

  @override
  String get studentVerificationChangeEmailInstruction =>
      'Note: Please enter a new school email address. After changing, re-verification is required.';

  @override
  String get studentVerificationBenefitCampusLife => 'Post Campus Life Tasks';

  @override
  String get studentVerificationBenefitCampusLifeDescription =>
      'Post and participate in campus life related tasks';

  @override
  String get studentVerificationBenefitStudentCommunity =>
      'Access Student Community';

  @override
  String get studentVerificationBenefitStudentCommunityDescription =>
      'Access exclusive student forum sections and interact with schoolmates';

  @override
  String get studentVerificationBenefitExclusiveBenefits =>
      'Student-Exclusive Benefits';

  @override
  String get studentVerificationBenefitExclusiveBenefitsDescription =>
      'Enjoy student discounts, exclusive events and more privileges';

  @override
  String get studentVerificationBenefitVerificationBadge =>
      'Verification Badge';

  @override
  String get studentVerificationBenefitVerificationBadgeDescription =>
      'Display student verification badge on profile to increase trust';

  @override
  String get studentVerificationVerificationEmail => 'Verification Email';

  @override
  String get studentVerificationVerificationTime => 'Verification Time';

  @override
  String get studentVerificationExpiryTime => 'Expiry Time';

  @override
  String get studentVerificationDaysRemaining => 'Days Remaining';

  @override
  String studentVerificationDaysFormat(int param1) {
    return '$param1 days';
  }

  @override
  String get studentVerificationSubmitting => 'Submitting...';

  @override
  String get studentVerificationSendEmail => 'Send Verification Email';

  @override
  String get studentVerificationRenewing => 'Renewing...';

  @override
  String get studentVerificationRenewNow => 'Renew Now';

  @override
  String get studentVerificationChanging => 'Changing...';

  @override
  String get studentVerificationConfirmChange => 'Confirm Change';

  @override
  String get studentVerificationVerified => 'Verified';

  @override
  String get studentVerificationUnverified => 'Unverified';

  @override
  String get studentVerificationStatusPending => 'Pending';

  @override
  String get studentVerificationStatusExpired => 'Expired';

  @override
  String get studentVerificationStatusRevoked => 'Revoked';

  @override
  String get studentVerificationBenefitsTitleVerified =>
      'Student Benefits You Enjoy';

  @override
  String get studentVerificationBenefitsTitleUnverified =>
      'After verification, you will get';

  @override
  String get customerServiceCustomerService => 'Customer Service';

  @override
  String get customerServiceChatWithService => 'Chat with Customer Service';

  @override
  String get activityActivity => 'Activity';

  @override
  String get activityRecentActivity => 'Recent Activity';

  @override
  String get activityPostedForumPost => 'posted a forum post';

  @override
  String get activityPostedFleaMarketItem => 'posted a flea market item';

  @override
  String get activityCreatedLeaderboard => 'created a leaderboard';

  @override
  String get activityEnded => 'Ended';

  @override
  String get activityFull => 'Full';

  @override
  String get activityApply => 'Apply to Join';

  @override
  String get activityApplied => 'Applied';

  @override
  String get activityParticipated => 'Participated';

  @override
  String get activityApplyToJoin => 'Apply to Join Activity';

  @override
  String get searchSearch => 'Search';

  @override
  String get searchResults => 'Results';

  @override
  String get searchNoResults => 'No results found';

  @override
  String get searchTryOtherKeywords => 'Try other keywords';

  @override
  String get searchPlaceholder => 'Search tasks, experts, items...';

  @override
  String get searchTaskPlaceholder => 'Search tasks';

  @override
  String get errorNetworkError => 'Network Error';

  @override
  String get errorUnknownError => 'Unknown Error';

  @override
  String get errorInvalidInput => 'Invalid Input';

  @override
  String get errorLoginFailed => 'Login Failed';

  @override
  String get errorRegisterFailed => 'Registration Failed';

  @override
  String get errorError => 'Error';

  @override
  String get errorRetry => 'Retry';

  @override
  String get errorSomethingWentWrong => 'Something went wrong';

  @override
  String get errorInvalidUrl => 'Invalid request URL, please try again later';

  @override
  String get errorNetworkConnectionFailed =>
      'Network connection failed, please check your network settings';

  @override
  String get errorRequestTimeout => 'Request timeout, please try again later';

  @override
  String get errorNetworkRequestFailed =>
      'Network request failed, please try again later';

  @override
  String get errorInvalidResponse =>
      'Server response error, please try again later';

  @override
  String get errorBadRequest => 'Invalid request parameters';

  @override
  String get errorUnauthorized => 'Login expired, please login again';

  @override
  String get errorForbidden => 'No permission to perform this operation';

  @override
  String get errorNotFound => 'Requested resource does not exist';

  @override
  String get errorTooManyRequests =>
      'Too many requests, please try again later';

  @override
  String get errorServerError => 'Server error, please try again later';

  @override
  String errorRequestFailed(int param1) {
    return 'Request failed (Error code: $param1)';
  }

  @override
  String get errorDecodingError =>
      'Data parsing failed, please try again later';

  @override
  String get errorUnknown => 'Unknown error occurred, please try again later';

  @override
  String get errorFileTooLarge => 'File too large';

  @override
  String errorFileTooLargeWithDetail(String param1) {
    return 'File too large: $param1';
  }

  @override
  String errorRequestFailedWithReason(String param1) {
    return 'Request failed: $param1';
  }

  @override
  String get errorInvalidResponseBody => 'Invalid response';

  @override
  String errorServerErrorCode(int param1) {
    return 'Server error (code: $param1)';
  }

  @override
  String errorServerErrorCodeWithMessage(String param1, int param2) {
    return 'Server error (code: $param2): $param1';
  }

  @override
  String errorDecodingErrorWithReason(String param1) {
    return 'Data parsing error: $param1';
  }

  @override
  String get errorCodeEmailAlreadyUsed =>
      'This email is already used by another account';

  @override
  String get errorCodeEmailAlreadyExists =>
      'This email is already registered. Use another email or log in';

  @override
  String get errorCodePhoneAlreadyUsed =>
      'This phone number is already used by another account';

  @override
  String get errorCodePhoneAlreadyExists =>
      'This phone number is already registered. Use another or log in';

  @override
  String get errorCodeUsernameAlreadyExists =>
      'This username is already taken. Please choose another';

  @override
  String get errorCodeCodeInvalidOrExpired =>
      'Verification code is invalid or expired. Please request a new one';

  @override
  String get errorCodeSendCodeFailed =>
      'Failed to send verification code. Please try again later';

  @override
  String get errorCodeEmailUpdateNeedCode =>
      'Please send a verification code to your new email first';

  @override
  String get errorCodePhoneUpdateNeedCode =>
      'Please send a verification code to your new phone number first';

  @override
  String get errorCodeTempEmailNotAllowed =>
      'Temporary email addresses are not allowed. Please use a real email';

  @override
  String get errorCodeLoginRequired => 'Please log in to view';

  @override
  String get errorCodeForbiddenView =>
      'You don\'t have permission to view this';

  @override
  String get errorCodeTaskAlreadyApplied =>
      'You have already applied for this task';

  @override
  String get errorCodeDisputeAlreadySubmitted =>
      'You have already submitted a dispute. Please wait for review';

  @override
  String get errorCodeRebuttalAlreadySubmitted =>
      'You have already submitted a rebuttal';

  @override
  String get errorCodeTaskNotPaid =>
      'Task is not paid yet. Please complete payment first';

  @override
  String get errorCodeTaskPaymentUnavailable =>
      'Payment is no longer available for this task';

  @override
  String get errorCodeStripeDisputeFrozen =>
      'This task is frozen due to a Stripe dispute. Please wait for it to be resolved';

  @override
  String get errorCodeStripeSetupRequired =>
      'Please complete payout account setup first';

  @override
  String get errorCodeStripeOtherPartyNotSetup =>
      'The other party has not set up their payout account. Please ask them to complete setup';

  @override
  String get errorCodeStripeAccountNotVerified =>
      'Payout account is not verified yet. Please complete account verification';

  @override
  String get errorCodeStripeAccountInvalid =>
      'Payout account is invalid. Please set it up again';

  @override
  String get errorCodeStripeVerificationFailed =>
      'Payout account verification failed. Please check your network and try again';

  @override
  String get errorCodeRefundAmountRequired =>
      'Please enter refund amount or percentage';

  @override
  String get errorCodeEvidenceFilesLimit => 'Too many evidence files';

  @override
  String get errorCodeEvidenceTextLimit =>
      'Evidence text must be 500 characters or less';

  @override
  String get errorCodeAccountHasActiveTasks =>
      'Cannot delete account: you have active tasks. Complete or cancel them first';

  @override
  String get errorCodeTempEmailNoPasswordReset =>
      'Temporary email cannot receive password reset. Please update your email in Settings';

  @override
  String get stripeDashboard => 'Stripe Dashboard';

  @override
  String get stripeConnectInitFailed =>
      'Unable to initialise payout account setup';

  @override
  String get stripeConnectLoadFailed =>
      'Payout setup failed to load, please try again';

  @override
  String get stripeConnectOnboardingCancelled =>
      'Payment account setup was cancelled';

  @override
  String get stripeConnectOnboardingFailed => 'Payment account setup failed';

  @override
  String get stripeConnectOnboardingErrorHint =>
      'If you see \"Sorry, something went wrong\" in the page, check your network or try again later; ensure the app and backend use the same Stripe environment (test/live).';

  @override
  String stripeConnectLoadFailedWithReason(String param1) {
    return 'Load failed: $param1';
  }

  @override
  String get stripeConnectOpenDashboard => 'Open Stripe Dashboard';

  @override
  String get stripeConnectDashboardUnavailable =>
      'Unable to open Stripe dashboard';

  @override
  String get stripeOnboardingCreateFailed =>
      'Unable to create payout setup session, please try again';

  @override
  String uploadNetworkErrorWithReason(String param1) {
    return 'Network error: $param1';
  }

  @override
  String get uploadCannotConnectServer =>
      'Cannot connect to server, please try again later';

  @override
  String get uploadBadRequestFormatImage =>
      'Invalid request format, please check image format';

  @override
  String get uploadBadRequestRetry => 'Invalid request, please try again';

  @override
  String get uploadFileTooLargeChooseSmaller =>
      'File too large, please choose a smaller file';

  @override
  String get uploadForbiddenUploadImage => 'No permission to upload image';

  @override
  String get uploadForbiddenUploadFile => 'No permission to upload file';

  @override
  String get uploadImageTooLarge =>
      'Image too large, please choose a smaller one';

  @override
  String uploadImageTooLargeWithMessage(String param1) {
    return 'Image too large: $param1';
  }

  @override
  String uploadServerErrorRetry(int param1) {
    return 'Server error ($param1), please try again later';
  }

  @override
  String uploadServerErrorCode(int param1) {
    return 'Server error ($param1)';
  }

  @override
  String uploadBadRequestWithMessage(String param1) {
    return 'Invalid request: $param1';
  }

  @override
  String uploadServerErrorCodeWithMessage(String param1, int param2) {
    return 'Server error ($param2): $param1';
  }

  @override
  String uploadParseResponseFailed(String param1) {
    return 'Failed to parse response: $param1';
  }

  @override
  String get uploadInvalidResponseFormat => 'Invalid server response format';

  @override
  String get uploadUnknownRetry => 'Unknown error, please try again';

  @override
  String uploadAllFailed(String param1) {
    return 'All image uploads failed.\\n$param1';
  }

  @override
  String uploadPartialFailed(String param1) {
    return 'Some image uploads failed:\\n$param1';
  }

  @override
  String uploadPartialFailedContinue(String param1) {
    return 'Some image uploads failed, continuing with uploaded images:\\n$param1';
  }

  @override
  String uploadImageIndexError(String param1, int param2) {
    return 'Image $param2: $param1';
  }

  @override
  String get refundForbidden => 'No permission to submit refund request';

  @override
  String get refundTaskNotFound => 'Task not found or no access';

  @override
  String get refundBadRequestFormat =>
      'Invalid request, please check your input';

  @override
  String get successOperationSuccess => 'Operation Successful';

  @override
  String get successSaved => 'Saved';

  @override
  String get successDeleted => 'Deleted';

  @override
  String get successRefreshSuccess => 'Refresh successful';

  @override
  String get successRefreshSuccessMessage =>
      'Item refreshed, auto-removal timer reset';

  @override
  String get currencyPound => '£';

  @override
  String get currencyPoints => 'Points';

  @override
  String get pointsBalance => 'Points Balance';

  @override
  String get pointsUnit => 'Points';

  @override
  String get pointsTotalEarned => 'Total Earned';

  @override
  String get pointsTotalSpent => 'Total Spent';

  @override
  String get pointsBalanceAfter => 'Balance';

  @override
  String pointsAmountFormat(int param1) {
    return '$param1 Points';
  }

  @override
  String pointsBalanceFormat(int param1) {
    return 'Balance: $param1 Points';
  }

  @override
  String get pointsPoints => 'Points';

  @override
  String get pointsPointsAndPayment => 'Points + Payment';

  @override
  String get pointsPointsDeduction => 'Points Deduction';

  @override
  String get pointsCheckIn => 'Check In';

  @override
  String get pointsCheckedInToday => 'Checked In Today';

  @override
  String get pointsCheckInReward => 'Check In for Points';

  @override
  String get pointsCheckInDescription =>
      '• Daily check-in rewards points\\n• More consecutive days, more rewards\\n• Consecutive days reset after interruption';

  @override
  String get pointsTransactionHistory =>
      'Your point transaction history will be displayed here';

  @override
  String get pointsNoTransactionHistory => 'No transaction history';

  @override
  String get pointsPointsAndCoupons => 'Points & Coupons';

  @override
  String get pointsShowRecentOnly => 'Show recent records only';

  @override
  String get couponCoupons => 'Coupons';

  @override
  String get couponCheckIn => 'Check In';

  @override
  String get couponAllowed => 'Allowed';

  @override
  String get couponForbidden => 'Forbidden';

  @override
  String get couponCheckInRules => 'Check-in Rules';

  @override
  String get couponStatusUnused => 'Unused';

  @override
  String get couponStatusUsed => 'Used';

  @override
  String get couponStatusExpired => 'Expired';

  @override
  String get couponTypeFixedAmount => 'Fixed Discount';

  @override
  String get couponTypePercentage => 'Percentage Off';

  @override
  String get pointsTypeEarn => 'Points Earned';

  @override
  String get pointsTypeSpend => 'Points Spent';

  @override
  String get pointsTypeRefund => 'Points Refunded';

  @override
  String get pointsTypeExpire => 'Points Expired';

  @override
  String get pointsTypeCouponRedeem => 'Coupon Redeemed';

  @override
  String get timeJustNow => 'Just now';

  @override
  String timeMinutesAgo(int minutes) {
    return '$minutes min ago';
  }

  @override
  String timeHoursAgo(int hours) {
    return '$hours hr ago';
  }

  @override
  String timeDaysAgo(int days) {
    return '${days}d ago';
  }

  @override
  String timeWeeksAgo(int param1) {
    return '$param1 weeks ago';
  }

  @override
  String timeMonthsAgo(int param1) {
    return '$param1 months ago';
  }

  @override
  String timeYearsAgo(int param1) {
    return '$param1 years ago';
  }

  @override
  String timeSecondsAgo(int param1) {
    return '$param1 seconds ago';
  }

  @override
  String get timeDeadlineUnknown => 'Deadline unknown';

  @override
  String get timeExpired => 'Expired';

  @override
  String timeMonths(int param1) {
    return '$param1 months';
  }

  @override
  String timeWeeks(int param1) {
    return '$param1 weeks';
  }

  @override
  String timeDays(int param1) {
    return '$param1 days';
  }

  @override
  String timeHours(int param1) {
    return '$param1 hours';
  }

  @override
  String timeMinutes(int param1) {
    return '$param1 minutes';
  }

  @override
  String timeSeconds(int param1) {
    return '$param1 seconds';
  }

  @override
  String get timeMonthDayFormat => 'MMM d';

  @override
  String get timeYearMonthDayFormat => 'MMM d, yyyy';

  @override
  String timeDurationHoursMinutes(int param1, int param2) {
    return '$param1 hours $param2 minutes';
  }

  @override
  String timeDurationMinutesSeconds(int param1, int param2) {
    return '$param1 minutes $param2 seconds';
  }

  @override
  String timeDurationSeconds(int param1) {
    return '$param1 seconds';
  }

  @override
  String get timeWan => 'k';

  @override
  String get timeWanPlus => '+';

  @override
  String get tabsHome => 'Home';

  @override
  String get tabsCommunity => 'Community';

  @override
  String get tabsCreate => 'Create';

  @override
  String get tabsMessages => 'Messages';

  @override
  String get tabsProfile => 'Profile';

  @override
  String get communityForum => 'Forum';

  @override
  String get communityLeaderboard => 'Leaderboard';

  @override
  String get communitySearchForumHint => 'Search forums';

  @override
  String get communitySearchLeaderboardHint => 'Search leaderboards';

  @override
  String get postPinned => 'Pinned';

  @override
  String get postFeatured => 'Featured';

  @override
  String get postOfficial => 'Official';

  @override
  String get postAll => 'All';

  @override
  String get actionsApprove => 'Approve';

  @override
  String get actionsReject => 'Reject';

  @override
  String get actionsChat => 'Chat';

  @override
  String get actionsShare => 'Share';

  @override
  String get actionsCancel => 'Cancel';

  @override
  String get actionsConfirm => 'Confirm';

  @override
  String get actionsSubmit => 'Submit';

  @override
  String get actionsLoadingMessages => 'Loading messages...';

  @override
  String get actionsNoMessagesYet => 'No messages yet';

  @override
  String get actionsStartConversation => 'Start a conversation!';

  @override
  String get actionsEnterMessage => 'Enter message...';

  @override
  String get actionsPrivateMessage => 'Private Message';

  @override
  String get actionsProcessing => 'Processing...';

  @override
  String get actionsMarkComplete => 'Mark Task Complete';

  @override
  String get actionsConfirmComplete => 'Confirm Task Complete';

  @override
  String get actionsContactRecipient => 'Contact Recipient';

  @override
  String get actionsContactPoster => 'Contact Poster';

  @override
  String get actionsRateTask => 'Rate Task';

  @override
  String get actionsCancelTask => 'Cancel Task';

  @override
  String get actionsApplyForTask => 'Apply for Task';

  @override
  String get actionsOptionalMessage => 'Message (Optional)';

  @override
  String get actionsNegotiatePrice => 'Negotiate Price';

  @override
  String get actionsApplyReasonHint =>
      'Explain your application reason to the publisher to improve success rate';

  @override
  String get actionsSubmitApplication => 'Submit Application';

  @override
  String get actionsCancelReason => 'Cancel Reason (Optional)';

  @override
  String get actionsShareTo => 'Share to...';

  @override
  String get profileUser => 'User';

  @override
  String get profileMyTasksSubtitle => 'View tasks I published and accepted';

  @override
  String get profileMyPostsSubtitle => 'Manage my second-hand items';

  @override
  String get profileMyWallet => 'My Wallet';

  @override
  String get profileMyWalletSubtitle => 'View balance and transaction history';

  @override
  String get profileMyApplications => 'My Activities';

  @override
  String get profileMyApplicationsSubtitle =>
      'View applied and favorited activities';

  @override
  String get profilePointsCoupons => 'Points & Coupons';

  @override
  String get profilePointsCouponsSubtitle =>
      'View points, coupons and check-in';

  @override
  String get profileStudentVerification => 'Student Verification';

  @override
  String get profileStudentVerificationSubtitle =>
      'Verify student identity for discounts';

  @override
  String get profileActivity => 'Activity';

  @override
  String get profileActivitySubtitle => 'View and participate in activities';

  @override
  String get profileSettingsSubtitle => 'App settings and preferences';

  @override
  String get profileWelcome => 'Welcome to Link²Ur';

  @override
  String get profileLoginPrompt => 'Login to access all features';

  @override
  String get profileConfirmLogout => 'Confirm Logout';

  @override
  String get profileLogoutMessage => 'Are you sure you want to logout?';

  @override
  String get taskDetailTaskDetail => 'Task Details';

  @override
  String get taskDetailShare => 'Share';

  @override
  String get taskDetailCancelTask => 'Cancel Task';

  @override
  String get taskDetailCancelTaskConfirm =>
      'Are you sure you want to cancel this task?';

  @override
  String get taskDetailNoTaskImages => 'No task images';

  @override
  String get taskDetailVipTask => 'VIP Task';

  @override
  String get taskDetailSuperTask => 'Super Task';

  @override
  String get taskDetailTaskDescription => 'Task Description';

  @override
  String get taskDetailTimeInfo => 'Time Information';

  @override
  String get taskDetailPublishTime => 'Publish Time';

  @override
  String get taskDetailDeadline => 'Deadline';

  @override
  String get taskDetailPublisher => 'Publisher';

  @override
  String get taskDetailRecipient => 'Recipient';

  @override
  String get taskDetailBuyer => 'Buyer';

  @override
  String get taskDetailSeller => 'Seller';

  @override
  String get taskDetailParticipant => 'Participant';

  @override
  String get taskDetailApplicant => 'Applicant';

  @override
  String get taskDetailEmailNotProvided => 'Email not provided';

  @override
  String get taskDetailYourTask => 'This is your task';

  @override
  String get taskDetailManageTask =>
      'You can view applicants and manage the task below';

  @override
  String taskDetailReviews(int param1) {
    return 'Reviews ($param1)';
  }

  @override
  String get taskDetailMyReviews => 'My Reviews';

  @override
  String get taskDetailAnonymousUser => 'Anonymous User';

  @override
  String get taskDetailUnknownUser => 'Unknown User';

  @override
  String get taskDetailApplyInfo => 'Application Info';

  @override
  String get taskDetailPriceNegotiation => 'Price Negotiation';

  @override
  String get taskDetailApplyReasonHint =>
      'Explain your application reason to the publisher to improve success rate';

  @override
  String get taskDetailSubmitApplication => 'Submit Application';

  @override
  String taskDetailApplicantsList(int param1) {
    return 'Applicants List ($param1)';
  }

  @override
  String get taskDetailNoApplicants => 'No applicants';

  @override
  String taskDetailMessageLabel(String param1) {
    return 'Message: $param1';
  }

  @override
  String get taskDetailWaitingReview => 'Waiting for publisher review';

  @override
  String get taskDetailTaskCompleted => 'Task Completed';

  @override
  String get taskDetailApplicationApproved => 'Application Approved';

  @override
  String get taskDetailApplicationRejected => 'Application Rejected';

  @override
  String get taskDetailUnknownStatus => 'Unknown Status';

  @override
  String get taskDetailApplicationSuccess => 'Application Successful';

  @override
  String get taskDetailApplicationSuccessMessage =>
      'You have successfully applied for this task. Please wait for the publisher to review.';

  @override
  String get taskDetailTaskCompletedMessage =>
      'Congratulations! You have completed the task. Please wait for the publisher to confirm.';

  @override
  String get taskDetailConfirmCompletionSuccess => 'Task Completion Confirmed';

  @override
  String get taskDetailTaskAlreadyReviewed => 'Task already reviewed';

  @override
  String get taskDetailReviewTitle => 'Rate Task';

  @override
  String get taskDetailReviewCommentHint => 'Share your experience (optional)';

  @override
  String get taskDetailReviewAnonymous => 'Anonymous review';

  @override
  String get taskDetailReviewSubmit => 'Submit review';

  @override
  String get taskDetailCompleteTaskSuccess => 'Completion submitted';

  @override
  String get taskDetailConfirmCompletionSuccessMessage =>
      'Task status has been updated to completed. Rewards will be automatically transferred to the task recipient.';

  @override
  String get refundRequestSubmitted => 'Refund request submitted';

  @override
  String get refundRebuttalSubmitted => 'Rebuttal submitted';

  @override
  String get taskDetailApplicationApprovedMessage =>
      'Congratulations! Your application has been approved. You can start working on the task.';

  @override
  String get taskDetailPendingPaymentMessage =>
      'The task poster is paying the platform service fee. The task will start after payment is completed.';

  @override
  String get taskDetailApplicationRejectedMessage =>
      'Sorry, your application was not approved.';

  @override
  String get taskDetailAlreadyApplied =>
      'You have already applied for this task.';

  @override
  String get taskDetailTaskAcceptedByOthers =>
      'This task has been accepted by another user.';

  @override
  String get taskDetailPendingReview => 'Pending Review';

  @override
  String get taskDetailApproved => 'Approved';

  @override
  String get taskDetailRejected => 'Rejected';

  @override
  String get taskDetailRejectApplication => 'Reject Application';

  @override
  String get taskDetailRejectApplicationConfirm =>
      'Are you sure you want to reject this application? This action cannot be undone.';

  @override
  String get taskDetailUnknown => 'Unknown';

  @override
  String get taskApplicationMessage => 'Message';

  @override
  String get taskApplicationMessageHint =>
      'Write a message to the applicant...';

  @override
  String get taskApplicationMessageSent => 'Message sent';

  @override
  String get taskApplicationMessageFailed => 'Failed to send message';

  @override
  String get taskDetailQualityGood => 'Good Quality';

  @override
  String get taskDetailOnTime => 'On Time';

  @override
  String get taskDetailResponsible => 'Responsible';

  @override
  String get taskDetailGoodAttitude => 'Good Attitude';

  @override
  String get taskDetailSkilled => 'Skilled';

  @override
  String get taskDetailTrustworthy => 'Trustworthy';

  @override
  String get taskDetailRecommended => 'Recommended';

  @override
  String get taskDetailExcellent => 'Excellent';

  @override
  String get taskDetailTaskClear => 'Clear Task';

  @override
  String get taskDetailCommunicationTimely => 'Timely Communication';

  @override
  String get taskDetailPaymentTimely => 'Timely Payment';

  @override
  String get taskDetailReasonableRequirements => 'Reasonable Requirements';

  @override
  String get taskDetailPleasantCooperation => 'Pleasant Cooperation';

  @override
  String get taskDetailProfessionalEfficient => 'Professional & Efficient';

  @override
  String get messagesLoadingMessages => 'Loading messages...';

  @override
  String get messagesNoMessagesYet => 'No messages yet';

  @override
  String get messagesStartConversation => 'Start a conversation!';

  @override
  String get messagesNoTaskChats => 'No Task Chats';

  @override
  String get messagesNoTaskChatsMessage => 'No task-related chat records yet';

  @override
  String get messagesCustomerService => 'Customer Service';

  @override
  String get messagesContactService => 'Contact customer service for help';

  @override
  String get messagesInteractionInfo => 'Interaction Info';

  @override
  String get messagesViewForumInteractions => 'View forum interaction messages';

  @override
  String get messagesNoInteractions => 'No Interactions';

  @override
  String get messagesNoInteractionsMessage =>
      'No interaction notifications yet';

  @override
  String get messagesClickToView => 'Click to view messages';

  @override
  String get messagesLoadingMore => 'Loading...';

  @override
  String get messagesLoadMoreHistory => 'Load more history';

  @override
  String get permissionLocationUsageDescription =>
      'We need to access your location information to provide you with more accurate services and task recommendations';

  @override
  String get customerServiceWelcome => 'Welcome to Customer Service';

  @override
  String get customerServiceStartConversation =>
      'Click the connect button below to start chatting with customer service';

  @override
  String get customerServiceLoadingMessages => 'Loading messages...';

  @override
  String customerServiceQueuePosition(int param1) {
    return 'Queue Position: No. $param1';
  }

  @override
  String customerServiceEstimatedWait(int param1) {
    return 'Estimated Wait Time: $param1 seconds';
  }

  @override
  String get customerServiceConversationEnded => 'Conversation ended';

  @override
  String get customerServiceNewConversation => 'New Conversation';

  @override
  String get customerServiceEnterMessage => 'Enter message...';

  @override
  String get customerServiceConnecting => 'Connecting to customer service...';

  @override
  String get customerServiceEndConversation => 'End Conversation';

  @override
  String get customerServiceHistory => 'History';

  @override
  String get customerServiceLoginRequired =>
      'Please login first to use customer service';

  @override
  String get customerServiceWhatCanHelp => 'How can we help you?';

  @override
  String get customerServiceNoChatHistory => 'No Chat History';

  @override
  String get customerServiceStartNewConversation => 'Start a new conversation!';

  @override
  String get customerServiceChatHistory => 'Chat History';

  @override
  String get customerServiceDone => 'Done';

  @override
  String get customerServiceServiceChat => 'Service Chat';

  @override
  String get customerServiceEnded => 'Ended';

  @override
  String get customerServiceInProgress => 'In Progress';

  @override
  String get customerServiceRateService => 'Rate Service';

  @override
  String customerServiceSatisfactionQuestion(String param1) {
    return 'Are you satisfied with $param1\'s service?';
  }

  @override
  String get customerServiceSelectRating => 'Please select a rating';

  @override
  String get customerServiceRatingContent => 'Rating Content (Optional)';

  @override
  String get customerServiceSubmitRating => 'Submit Rating';

  @override
  String get customerServiceRateServiceTitle => 'Rate Service';

  @override
  String get customerServiceSkip => 'Skip';

  @override
  String get ratingVeryPoor => 'Very Poor';

  @override
  String get ratingPoor => 'Poor';

  @override
  String get ratingAverage => 'Average';

  @override
  String get ratingGood => 'Good';

  @override
  String get ratingExcellent => 'Excellent';

  @override
  String get ratingRating => 'Rating';

  @override
  String get ratingSelectTags => 'Select Tags (Optional)';

  @override
  String get ratingComment => 'Comment (Optional)';

  @override
  String get ratingAnonymous => 'Anonymous Rating';

  @override
  String get ratingSubmit => 'Submit Rating';

  @override
  String get ratingSuccess => 'Review submitted';

  @override
  String get ratingAnonymousRating => 'Anonymous Rating';

  @override
  String get ratingSubmitRating => 'Submit Rating';

  @override
  String ratingHalfStar(String param1) {
    return '$param1 stars';
  }

  @override
  String get rating05Stars => '0.5 stars';

  @override
  String get rating15Stars => '1.5 stars';

  @override
  String get rating25Stars => '2.5 stars';

  @override
  String get rating35Stars => '3.5 stars';

  @override
  String get rating45Stars => '4.5 stars';

  @override
  String get ratingTagHighQuality => 'High Quality';

  @override
  String get ratingTagOnTime => 'On Time';

  @override
  String get ratingTagResponsible => 'Responsible';

  @override
  String get ratingTagGoodCommunication => 'Good Communication';

  @override
  String get ratingTagProfessionalEfficient => 'Professional & Efficient';

  @override
  String get ratingTagTrustworthy => 'Trustworthy';

  @override
  String get ratingTagStronglyRecommended => 'Strongly Recommended';

  @override
  String get ratingTagExcellent => 'Excellent';

  @override
  String get ratingTagClearTask => 'Clear Task Description';

  @override
  String get ratingTagTimelyCommunication => 'Timely Communication';

  @override
  String get ratingTagTimelyPayment => 'Timely Payment';

  @override
  String get ratingTagReasonableRequirements => 'Reasonable Requirements';

  @override
  String get ratingTagPleasantCooperation => 'Pleasant Cooperation';

  @override
  String get ratingTagVeryProfessional => 'Very Professional';

  @override
  String get taskApplicationApplyTask => 'Apply for Task';

  @override
  String get taskApplicationIWantToNegotiatePrice =>
      'I want to negotiate price';

  @override
  String get taskApplicationExpectedAmount => 'Expected Amount';

  @override
  String get taskApplicationNegotiatePriceHint =>
      'Tip: Negotiating price may affect the publisher\'s choice.';

  @override
  String get taskApplicationSubmitApplication => 'Submit Application';

  @override
  String get taskApplicationMessageToApplicant => 'Message to applicant...';

  @override
  String get taskApplicationIsNegotiatePrice => 'Is Negotiate Price';

  @override
  String get taskApplicationNegotiateAmount => 'Negotiate Amount';

  @override
  String get taskApplicationSendMessage => 'Send Message';

  @override
  String get taskApplicationUnknownUser => 'Unknown User';

  @override
  String get taskApplicationAdvantagePlaceholder =>
      'Briefly explain your advantages or how to complete the task...';

  @override
  String get taskApplicationReviewPlaceholder =>
      'Write about your collaboration experience to help other users...';

  @override
  String get emptyNoTasks => 'No Tasks';

  @override
  String get emptyNoTasksMessage =>
      'No tasks have been posted yet. Be the first to post one!';

  @override
  String get emptyNoNotifications => 'No Notifications';

  @override
  String get emptyNoNotificationsMessage =>
      'No notification messages received yet';

  @override
  String get emptyNoPaymentRecords => 'No Payment Records';

  @override
  String get emptyNoPaymentRecordsMessage =>
      'Your payment records will be displayed here';

  @override
  String get paymentStatusSuccess => 'Success';

  @override
  String get paymentStatusProcessing => 'Processing';

  @override
  String get paymentStatusFailed => 'Failed';

  @override
  String get paymentStatusCanceled => 'Canceled';

  @override
  String get paymentStatusTaskPayment => 'Task Payment';

  @override
  String paymentTaskNumberWithId(int param1) {
    return 'Task #$param1';
  }

  @override
  String get notificationSystemMessages => 'System Messages';

  @override
  String get notificationViewAllNotifications => 'View All Notifications';

  @override
  String get customerServiceConversationEndedMessage =>
      'Conversation ended. Please start a new conversation if you need help.';

  @override
  String customerServiceConnected(String param1) {
    return '👋 Connected to customer service $param1';
  }

  @override
  String customerServiceTotalMessages(int param1) {
    return '$param1 messages';
  }

  @override
  String get paymentRecordsPaymentRecords => 'Payment Records';

  @override
  String get paymentRecordsLoading => 'Loading...';

  @override
  String get paymentRecordsLoadFailed => 'Load Failed';

  @override
  String get paymentNoPayoutRecords => 'No Payout Records';

  @override
  String get paymentNoPayoutRecordsMessage =>
      'Your payout records will be displayed here';

  @override
  String get paymentViewDetails => 'View Details';

  @override
  String get paymentPayout => 'Payout';

  @override
  String get paymentNoAvailableBalance => 'No Available Balance';

  @override
  String get paymentPayoutRecords => 'Payout Records';

  @override
  String get paymentTotalBalance => 'Total Balance';

  @override
  String get paymentAvailableBalance => 'Available Balance';

  @override
  String get paymentPending => 'Pending';

  @override
  String get paymentPayoutAmount => 'Payout Amount';

  @override
  String get paymentPayoutAmountTitle => 'Payout Amount';

  @override
  String get paymentIncomeAmount => 'Income Amount';

  @override
  String get paymentNoteOptional => 'Note (Optional)';

  @override
  String get paymentPayoutNote => 'Payout Note';

  @override
  String get paymentConfirmPayout => 'Confirm Payout';

  @override
  String get paymentAccountInfo => 'Account Info';

  @override
  String get paymentAccountDetails => 'Account Details';

  @override
  String get paymentOpenStripeDashboard => 'Open Stripe Dashboard';

  @override
  String get paymentExternalAccount => 'External Account';

  @override
  String get paymentNoExternalAccount => 'No External Account';

  @override
  String get paymentDetails => 'Details';

  @override
  String get paymentAccountId => 'Account ID';

  @override
  String get paymentDisplayName => 'Display Name';

  @override
  String get paymentCountry => 'Country';

  @override
  String get paymentAccountType => 'Account Type';

  @override
  String get paymentDetailsSubmitted => 'Details Submitted';

  @override
  String get paymentChargesEnabled => 'Charges Enabled';

  @override
  String get paymentPayoutsEnabled => 'Payouts Enabled';

  @override
  String get paymentYes => 'Yes';

  @override
  String get paymentNo => 'No';

  @override
  String get paymentBankAccount => 'Bank Account';

  @override
  String get paymentCard => 'Card';

  @override
  String get paymentBankName => 'Bank Name';

  @override
  String get paymentAccountLast4 => 'Account Last 4';

  @override
  String get paymentRoutingNumber => 'Routing Number';

  @override
  String get paymentAccountHolder => 'Account Holder';

  @override
  String get paymentHolderType => 'Holder Type';

  @override
  String get paymentIndividual => 'Individual';

  @override
  String get paymentCompany => 'Company';

  @override
  String get paymentStatus => 'Status';

  @override
  String get paymentCardBrand => 'Card Brand';

  @override
  String get paymentCardLast4 => 'Card Last 4';

  @override
  String get paymentExpiry => 'Expiry';

  @override
  String get paymentCardType => 'Type';

  @override
  String get paymentCreditCard => 'Credit Card';

  @override
  String get paymentDebitCard => 'Debit Card';

  @override
  String get paymentTransactionId => 'Transaction ID';

  @override
  String get paymentDescription => 'Description';

  @override
  String get paymentTime => 'Time';

  @override
  String get paymentType => 'Type';

  @override
  String get paymentIncome => 'Income';

  @override
  String get paymentSource => 'Source';

  @override
  String get paymentPayoutManagement => 'Payout Management';

  @override
  String get paymentTransactionDetails => 'Transaction Details';

  @override
  String get paymentAccountSetupComplete => 'Payment Account Setup Complete';

  @override
  String get paymentCanReceiveRewards => 'You can now receive task rewards';

  @override
  String get paymentAccountInfoBelow =>
      'Your account information is as follows';

  @override
  String get paymentRefreshAccountInfo => 'Refresh Account Info';

  @override
  String get paymentComplete => 'Complete';

  @override
  String get paymentCountdownExpired => 'Expired';

  @override
  String paymentCountdownRemaining(String time) {
    return 'Remaining $time';
  }

  @override
  String get paymentCountdownBannerTitle =>
      'Complete payment within 30 minutes';

  @override
  String paymentCountdownBannerSubtitle(String param1) {
    return 'Time remaining: $param1';
  }

  @override
  String get paymentCountdownBannerExpired =>
      'Payment expired, task will be cancelled';

  @override
  String couponMinAmountAvailable(String param1) {
    return 'Available for $param1 or more';
  }

  @override
  String get couponAvailable => 'Available';

  @override
  String couponDiscount(int param1) {
    return '$param1% Off';
  }

  @override
  String get couponMyCoupons => 'My Coupons';

  @override
  String get couponNoThreshold => 'No Threshold';

  @override
  String get couponClaimNow => 'Claim Now';

  @override
  String get couponAvailableCoupons => 'Available Coupons';

  @override
  String get couponRedeemSuccess => 'Redeem Success';

  @override
  String get couponRedeemFailed => 'Redeem Failed';

  @override
  String get couponEnterRedemptionCode => 'Enter Redemption Code';

  @override
  String get couponEnterRedemptionCodePlaceholder =>
      'Please enter redemption code';

  @override
  String get couponRedeem => 'Redeem';

  @override
  String get couponConfirmRedeem => 'Confirm Redeem';

  @override
  String couponConfirmRedeemWithPoints(int param1) {
    return 'Are you sure you want to redeem this coupon with $param1 points?';
  }

  @override
  String couponValidUntil(String param1) {
    return 'Valid Until: $param1';
  }

  @override
  String get couponNoAvailableCoupons => 'No Available Coupons';

  @override
  String get couponNoAvailableCouponsMessage =>
      'No coupons available to claim, stay tuned for events';

  @override
  String get couponNoMyCoupons => 'You have no coupons yet';

  @override
  String get couponNoMyCouponsMessage => 'Claimed coupons will appear here';

  @override
  String get couponUsageInstructions => 'Usage Instructions';

  @override
  String get couponTransactionHistory => 'Transaction History';

  @override
  String get couponCheckInReward => 'Check-in Rewards';

  @override
  String get couponCheckInComingSoon =>
      'Check-in rewards coming soon, stay tuned';

  @override
  String get couponCheckInSuccess => 'Check-in Successful';

  @override
  String get couponAwesome => 'Awesome';

  @override
  String couponDays(int param1) {
    return '$param1 days';
  }

  @override
  String get couponRememberTomorrow => 'Remember to come back tomorrow';

  @override
  String get couponConsecutiveReward => 'More consecutive days, more rewards';

  @override
  String get couponCheckInNow => 'Check In Now';

  @override
  String couponConsecutiveDays(int param1) {
    return 'Consecutive check-in for $param1 days';
  }

  @override
  String couponConsecutiveCheckIn(int days) {
    return '$days-day streak';
  }

  @override
  String get couponMemberOnly => 'Member Only';

  @override
  String couponLimitPerDay(int param1) {
    return '$param1 per day';
  }

  @override
  String couponLimitPerWeek(int param1) {
    return '$param1 per week';
  }

  @override
  String couponLimitPerMonth(int param1) {
    return '$param1 per month';
  }

  @override
  String couponLimitPerYear(int param1) {
    return '$param1 per year';
  }

  @override
  String get taskApplicationApplyInfo => 'Application Info';

  @override
  String get taskApplicationOverallRating => 'Overall Rating';

  @override
  String get taskApplicationRatingTags => 'Rating Tags';

  @override
  String get taskApplicationRatingContent => 'Rating Content';

  @override
  String get createTaskPublishing => 'Publishing...';

  @override
  String get createTaskPublishNow => 'Publish Task Now';

  @override
  String get createTaskPublishTask => 'Publish Task';

  @override
  String get createTaskTitle => 'Post Task';

  @override
  String get createTaskTitlePlaceholder => 'Enter task title';

  @override
  String get createTaskDescription => 'Task Details';

  @override
  String get createTaskDescriptionPlaceholder =>
      'Please describe your needs, time, special requirements, etc. in detail. The more detailed, the easier it is to get accepted...';

  @override
  String get createTaskReward => 'Reward';

  @override
  String get createTaskCity => 'City';

  @override
  String get createTaskOnline => 'Online';

  @override
  String get createTaskCampusLifeRestriction =>
      'Only verified students can post campus life tasks';

  @override
  String get studentVerificationStudentVerification => 'Student Verification';

  @override
  String get stripeConnectSetupAccount => 'Setup Payment Account';

  @override
  String get activityLoadFailed => 'Load Failed';

  @override
  String get activityPleaseRetry => 'Please retry';

  @override
  String get activityDescription => 'Activity Description';

  @override
  String get activityDetails => 'Details';

  @override
  String get activitySelectTimeSlot => 'Select Time Slot';

  @override
  String get activityNoAvailableTime => 'No Available Time';

  @override
  String get activityNoAvailableTimeMessage =>
      'No available time slots at the moment';

  @override
  String get activityParticipateTime => 'Participate Time';

  @override
  String get activityByAppointment => 'By Appointment';

  @override
  String get activityParticipants => 'Participants';

  @override
  String get activityRemainingSlots => 'Remaining Slots';

  @override
  String get activityStatus => 'Status';

  @override
  String get activityHotRecruiting => 'Open';

  @override
  String get activityLocation => 'Location';

  @override
  String get activityType => 'Type';

  @override
  String get activityTimeArrangement => 'Time Arrangement';

  @override
  String get activityMultipleTimeSlots =>
      'Supports multiple time slot bookings';

  @override
  String get activityDeadline => 'Deadline';

  @override
  String get activityExclusiveDiscount => 'Exclusive Discount';

  @override
  String get activityFilter => 'Filter';

  @override
  String get activityAll => 'All';

  @override
  String get activityActive => 'Active';

  @override
  String get activitySingle => 'Single';

  @override
  String get activityMulti => 'Group';

  @override
  String get activityTabAll => 'All';

  @override
  String get activityTabApplied => 'Applied';

  @override
  String get activityTabFavorited => 'Favorited';

  @override
  String get activityActivities => 'Activities';

  @override
  String get activityNoEndedActivities => 'No Ended Activities';

  @override
  String get activityNoEndedActivitiesMessage => 'No ended activity records';

  @override
  String get activityNoActivities => 'No Activities';

  @override
  String get activityNoActivitiesMessage => 'No activities yet, stay tuned...';

  @override
  String get activityFullCapacity => 'Full Capacity';

  @override
  String get activityPoster => 'Activity Poster';

  @override
  String get activityViewExpertProfile => 'View Expert Profile';

  @override
  String get activityFavorite => 'Favorite';

  @override
  String get activityTimeFlexible => 'Flexible Time';

  @override
  String get activityPreferredDate => 'Preferred Date';

  @override
  String get activityTimeFlexibleMessage =>
      'If you are available at any time in the near future';

  @override
  String get activityConfirmApply => 'Confirm Application';

  @override
  String get taskTypeSuperTask => 'Super Task';

  @override
  String get taskTypeVipTask => 'VIP Task';

  @override
  String get menuMenu => 'Menu';

  @override
  String get menuMy => 'My';

  @override
  String get menuTaskHall => 'Task Hall';

  @override
  String get menuTaskExperts => 'Task Experts';

  @override
  String get menuForum => 'Forum';

  @override
  String get menuLeaderboard => 'Leaderboard';

  @override
  String get menuFleaMarket => 'Flea Market';

  @override
  String get menuActivity => 'Activity';

  @override
  String get menuPointsCoupons => 'Points & Coupons';

  @override
  String get menuStudentVerification => 'Student Verification';

  @override
  String get menuSettings => 'Settings';

  @override
  String get menuClose => 'Close';

  @override
  String get taskCategoryAll => 'All';

  @override
  String get taskCategoryHousekeeping => 'Housekeeping';

  @override
  String get taskCategoryCampusLife => 'Campus Life';

  @override
  String get taskCategorySecondhandRental => 'Secondhand';

  @override
  String get taskCategoryErrandRunning => 'Errands';

  @override
  String get taskCategorySkillService => 'Skills';

  @override
  String get taskCategorySocialHelp => 'Social Help';

  @override
  String get taskCategoryTransportation => 'Transport';

  @override
  String get taskCategoryPetCare => 'Pet Care';

  @override
  String get taskCategoryLifeConvenience => 'Convenience';

  @override
  String get taskCategoryOther => 'Other';

  @override
  String get expertCategoryAll => 'All';

  @override
  String get expertCategoryProgramming => 'Programming';

  @override
  String get expertCategoryTranslation => 'Translation';

  @override
  String get expertCategoryTutoring => 'Tutoring';

  @override
  String get expertCategoryFood => 'Food';

  @override
  String get expertCategoryBeverage => 'Beverage';

  @override
  String get expertCategoryCake => 'Cake';

  @override
  String get expertCategoryErrandTransport => 'Errand/Transport';

  @override
  String get expertCategorySocialEntertainment => 'Social/Entertainment';

  @override
  String get expertCategoryBeautySkincare => 'Beauty/Skincare';

  @override
  String get expertCategoryHandicraft => 'Handicraft';

  @override
  String get cityLondon => 'London';

  @override
  String get cityEdinburgh => 'Edinburgh';

  @override
  String get cityManchester => 'Manchester';

  @override
  String get cityBirmingham => 'Birmingham';

  @override
  String get cityGlasgow => 'Glasgow';

  @override
  String get cityBristol => 'Bristol';

  @override
  String get citySheffield => 'Sheffield';

  @override
  String get cityLeeds => 'Leeds';

  @override
  String get cityNottingham => 'Nottingham';

  @override
  String get cityNewcastle => 'Newcastle';

  @override
  String get citySouthampton => 'Southampton';

  @override
  String get cityLiverpool => 'Liverpool';

  @override
  String get cityCardiff => 'Cardiff';

  @override
  String get cityCoventry => 'Coventry';

  @override
  String get cityExeter => 'Exeter';

  @override
  String get cityLeicester => 'Leicester';

  @override
  String get cityYork => 'York';

  @override
  String get cityAberdeen => 'Aberdeen';

  @override
  String get cityBath => 'Bath';

  @override
  String get cityDundee => 'Dundee';

  @override
  String get cityReading => 'Reading';

  @override
  String get cityStAndrews => 'St Andrews';

  @override
  String get cityBelfast => 'Belfast';

  @override
  String get cityBrighton => 'Brighton';

  @override
  String get cityDurham => 'Durham';

  @override
  String get cityNorwich => 'Norwich';

  @override
  String get citySwansea => 'Swansea';

  @override
  String get cityLoughborough => 'Loughborough';

  @override
  String get cityLancaster => 'Lancaster';

  @override
  String get cityWarwick => 'Warwick';

  @override
  String get cityCambridge => 'Cambridge';

  @override
  String get cityOxford => 'Oxford';

  @override
  String get taskFilterCategory => 'Category';

  @override
  String get taskFilterCity => 'City';

  @override
  String get taskFilterSelectCategory => 'Select Category';

  @override
  String get taskFilterSelectCity => 'Select City';

  @override
  String get createTaskBasicInfo => 'Basic Information';

  @override
  String get createTaskRewardLocation => 'Reward & Location';

  @override
  String get createTaskCurrency => 'Currency';

  @override
  String get createTaskTaskType => 'Task Type';

  @override
  String get createTaskImages => 'Images';

  @override
  String get createTaskAddImages => 'Add Images';

  @override
  String get createTaskFillAllRequired => 'Please fill in all required fields';

  @override
  String get createTaskImageUploadFailed =>
      'Some images failed to upload, please try again';

  @override
  String get createTaskStudentVerificationRequired =>
      'Only verified students can post campus life tasks';

  @override
  String get taskExpertBecomeExpert => 'Become Expert';

  @override
  String get taskExpertBecomeExpertTitle => 'Become a Task Expert';

  @override
  String get taskExpertShowcaseSkills =>
      'Showcase your professional skills and get more task opportunities';

  @override
  String get taskExpertBenefits => 'Benefits of Becoming an Expert';

  @override
  String get taskExpertHowToApply => 'How to Apply?';

  @override
  String get taskExpertApplyNow => 'Apply Now';

  @override
  String get taskExpertLoginToApply => 'Login to Apply';

  @override
  String get taskExpertApplicationInfo => 'Application Information';

  @override
  String get taskExpertApplicationHint =>
      'Please introduce your professional skills, experience and advantages. This will help the platform better understand you.';

  @override
  String get taskExpertSubmitApplication => 'Submit Application';

  @override
  String get taskExpertApplicationSubmitted => 'Application Submitted';

  @override
  String get taskExpertNoIntro => 'No Introduction';

  @override
  String get taskExpertServiceMenu => 'Service Menu';

  @override
  String get taskExpertOptionalTimeSlots => 'Optional Time Slots';

  @override
  String get taskExpertNoAvailableSlots => 'No Available Time Slots';

  @override
  String get taskExpertApplyService => 'Apply for Service';

  @override
  String get taskExpertOptional => 'Optional';

  @override
  String get taskExpertFull => 'Full';

  @override
  String get taskExpertApplicationMessage => 'Application Message';

  @override
  String get taskExpertNegotiatePrice => 'Negotiate Price';

  @override
  String get taskExpertExpertNegotiatePrice =>
      'Task Expert Proposed Price Negotiation:';

  @override
  String get taskExpertViewTask => 'View Task';

  @override
  String taskExpertTaskDetails(String param1) {
    return 'Task Details: $param1';
  }

  @override
  String get taskExpertClear => 'Clear';

  @override
  String get taskExpertApplied => 'Applied';

  @override
  String get taskExpertByAppointment => 'By Appointment';

  @override
  String get forumNeedLogin => 'Login Required';

  @override
  String get forumCommunityLoginMessage =>
      'Community features are only available to logged-in users who have completed student verification';

  @override
  String get forumLoginNow => 'Login Now';

  @override
  String get forumNeedStudentVerification => 'Student Verification Required';

  @override
  String get forumVerificationPending =>
      'Your student verification application is under review. Please wait patiently.';

  @override
  String get forumVerificationRejected =>
      'Your student verification application was not approved. Please resubmit.';

  @override
  String get forumCompleteVerification =>
      'Please complete student verification to access community features';

  @override
  String get forumCompleteVerificationMessage =>
      'Please complete student verification to access community features';

  @override
  String get forumGoVerify => 'Go Verify';

  @override
  String forumReplies(String param1) {
    return 'Replies ($param1)';
  }

  @override
  String forumLoadRepliesFailed(String param1) {
    return 'Failed to load replies: $param1';
  }

  @override
  String get forumNoReplies => 'No Comments';

  @override
  String get forumPostReply => 'Post Reply';

  @override
  String get forumSelectSection => 'Select Section';

  @override
  String get forumPleaseSelectSection => 'Please Select Section';

  @override
  String get forumPublish => 'Publish';

  @override
  String get forumSomeone => 'Someone';

  @override
  String get forumNotificationNewReply => 'New Reply';

  @override
  String get forumNotificationNewLike => 'New Like';

  @override
  String forumNotificationReplyPost(String param1) {
    return '$param1 replied to your post';
  }

  @override
  String forumNotificationReplyReply(String param1) {
    return '$param1 replied to your reply';
  }

  @override
  String forumNotificationLikePost(String param1) {
    return '$param1 liked your post';
  }

  @override
  String forumNotificationLikeReply(String param1) {
    return '$param1 liked your reply';
  }

  @override
  String get forumNotificationPinPost => 'Post Pinned';

  @override
  String get forumNotificationPinPostContent =>
      'Your post has been pinned by an administrator';

  @override
  String get forumNotificationFeaturePost => 'Post Featured';

  @override
  String get forumNotificationFeaturePostContent =>
      'Your post has been featured by an administrator';

  @override
  String get forumNotificationDefault => 'Forum Notification';

  @override
  String get forumNotificationDefaultContent =>
      'You received a forum notification';

  @override
  String get infoConnectPlatform => 'Connect You and Me Task Platform';

  @override
  String get infoContactUs => 'Contact Us';

  @override
  String get infoMemberBenefits => 'Member Benefits';

  @override
  String get infoFaq => 'FAQ';

  @override
  String get infoNeedHelp => 'Need Help?';

  @override
  String get infoContactAdmin =>
      'Contact administrator for more member information';

  @override
  String get infoContactService => 'Contact Service';

  @override
  String get infoTermsOfService => 'Terms of Service';

  @override
  String get infoPrivacyPolicy => 'Privacy Policy';

  @override
  String get infoLastUpdated => 'Last Updated: January 1, 2024';

  @override
  String get infoAboutUs => 'About Us';

  @override
  String get infoOurMission => 'Our Mission';

  @override
  String get infoOurVision => 'Our Vision';

  @override
  String get infoAboutUsContent =>
      'Link²Ur is an innovative task posting and taking platform dedicated to connecting people who need help with those willing to provide help. We believe everyone has their own skills and time, and through the platform, these resources can be better utilized.';

  @override
  String get infoOurMissionContent =>
      'Make task posting and taking simple, efficient, and safe. We are committed to building a trusted community platform where everyone can find suitable tasks and help others.';

  @override
  String get infoOurVisionContent =>
      'Become the most popular task platform in the UK, connecting thousands of users, creating more value, and making the community closer.';

  @override
  String get vipMember => 'VIP Member';

  @override
  String get vipBecomeVip => 'Become VIP Member';

  @override
  String get vipEnjoyBenefits => 'Enjoy exclusive benefits and privileges';

  @override
  String get vipUnlockPrivileges => 'Unlock more privileges and services';

  @override
  String get vipPriorityRecommendation => 'Priority Recommendation';

  @override
  String get vipPriorityRecommendationDesc =>
      'Your tasks and applications will be prioritized, gaining more exposure';

  @override
  String get vipFeeDiscount => 'Fee Discount';

  @override
  String get vipFeeDiscountDesc =>
      'Enjoy lower task posting fees, saving more costs';

  @override
  String get vipExclusiveBadge => 'Exclusive Badge';

  @override
  String get vipExclusiveBadgeDesc =>
      'Display exclusive VIP badge on profile to enhance your credibility';

  @override
  String get vipExclusiveActivity => 'Exclusive Activities';

  @override
  String get vipExclusiveActivityDesc =>
      'Participate in VIP exclusive activities and offers, get more rewards';

  @override
  String get vipFaqHowToUpgrade => 'How to upgrade membership?';

  @override
  String get vipFaqHowToUpgradeAnswer =>
      'The membership upgrade feature is currently under development. You can contact the administrator for manual upgrade, or wait for the automatic upgrade feature to be launched.';

  @override
  String get vipFaqWhenEffective => 'When do membership benefits take effect?';

  @override
  String get vipFaqWhenEffectiveAnswer =>
      'Membership benefits take effect immediately after upgrade, and you can immediately enjoy the corresponding privileged services.';

  @override
  String get vipFaqCanCancel => 'Can I cancel membership at any time?';

  @override
  String get vipFaqCanCancelAnswer =>
      'Yes, you can contact the administrator to cancel membership service at any time. The cancellation will take effect in the next billing cycle.';

  @override
  String get vipComingSoon => 'VIP feature coming soon, stay tuned!';

  @override
  String get vipSelectPackage => 'Choose the membership plan that suits you';

  @override
  String get vipNoProducts => 'No VIP products available';

  @override
  String get vipPerMonth => '/ month';

  @override
  String get vipPerYear => '/ year';

  @override
  String get vipTryLaterContact => 'Please try again later or contact support';

  @override
  String get vipPleaseSelectPackage => 'Please select a plan';

  @override
  String get vipBuyNow => 'Purchase Now';

  @override
  String get vipRestorePurchase => 'Restore Purchase';

  @override
  String get vipPurchaseInstructions => 'Purchase Instructions';

  @override
  String get vipSubscriptionAutoRenew =>
      '• Subscription will auto-renew unless cancelled at least 24 hours before expiry';

  @override
  String get vipManageSubscription =>
      '• Manage subscription in App Store account settings';

  @override
  String get vipPurchaseEffective =>
      '• Benefits take effect immediately after purchase';

  @override
  String get vipPurchaseTitle => 'Purchase VIP Membership';

  @override
  String get vipPurchaseSuccess => 'Purchase Successful';

  @override
  String get vipCongratulations =>
      'Congratulations on becoming a VIP member! Enjoy all VIP benefits.';

  @override
  String vipRestoreFailed(String param1) {
    return 'Restore failed: $param1';
  }

  @override
  String get vipPurchased => 'Purchased';

  @override
  String get vipAlreadyVip => 'You are already a VIP member';

  @override
  String get vipThankYou =>
      'Thank you for your support. Enjoy all VIP benefits.';

  @override
  String vipExpiryTime(String param1) {
    return 'Expires: $param1';
  }

  @override
  String get vipWillAutoRenew => 'Will auto-renew';

  @override
  String get vipAutoRenewCancelled => 'Auto-renew cancelled';

  @override
  String get vipFaqHowToUpgradeSteps =>
      'Tap the \'Upgrade to VIP\' button on the VIP membership page and choose a suitable plan to purchase.';

  @override
  String get serviceNoImages => 'No images';

  @override
  String get serviceDetail => 'Service Details';

  @override
  String get serviceNoDescription => 'No detailed description';

  @override
  String get serviceApplyMessage => 'Application Message';

  @override
  String get serviceExpectedPrice => 'Expected price';

  @override
  String get serviceFlexibleTime => 'Flexible time';

  @override
  String get serviceExpectedDate => 'Expected completion date';

  @override
  String get serviceSelectDate => 'Select date';

  @override
  String get serviceApplyTitle => 'Apply for Service';

  @override
  String get offlineMode => 'Offline mode';

  @override
  String offlinePendingSync(int param1) {
    return '($param1 pending sync)';
  }

  @override
  String get networkOffline => 'Network disconnected';

  @override
  String get networkDisconnected => 'Network disconnected';

  @override
  String get networkCheckSettings => 'Please check your network settings';

  @override
  String get networkRestored => 'Network restored';

  @override
  String get networkConnectedWifi => 'Connected to Wi-Fi';

  @override
  String get networkConnectedCellular => 'Connected to cellular';

  @override
  String get networkConnectedEthernet => 'Connected to Ethernet';

  @override
  String get networkConnected => 'Network connected';

  @override
  String notificationExpiresSeconds(double param1) {
    return 'Expires in $param1 seconds';
  }

  @override
  String notificationExpiresMinutes(int param1) {
    return 'Expires in $param1 minutes';
  }

  @override
  String notificationExpiresHours(int param1) {
    return 'Expires in $param1 hours';
  }

  @override
  String get notificationViewFull => 'View full';

  @override
  String notificationExpiryTime(String param1) {
    return 'Expiry: $param1';
  }

  @override
  String get notificationUnread => 'Unread';

  @override
  String get notificationContent => 'Notification content';

  @override
  String get notificationDetail => 'Notification Detail';

  @override
  String get notificationGetNegotiationFailed =>
      'Unable to load negotiation info. Please refresh and try again.';

  @override
  String get translationFailed => 'Translation Failed';

  @override
  String get translationRetryMessage =>
      'Unable to translate this message. Please check your network and try again.';

  @override
  String get taskDetailCollapse => 'Collapse';

  @override
  String get taskDetailExpandAll => 'Expand all';

  @override
  String taskDetailCompletedCount(int param1) {
    return '$param1 completed';
  }

  @override
  String get taskDetailExpired => 'Expired';

  @override
  String taskDetailRemainingMinutes(int param1) {
    return '$param1 min remaining';
  }

  @override
  String taskDetailRemainingHours(int param1) {
    return '$param1 hrs remaining';
  }

  @override
  String taskDetailRemainingDays(int param1) {
    return '$param1 days remaining';
  }

  @override
  String get walletQuickActions => 'Quick Actions';

  @override
  String get walletRecentTransactions => 'Recent Transactions';

  @override
  String get walletBalance => 'Wallet Balance';

  @override
  String get walletMyWallet => 'My Wallet';

  @override
  String get walletPaymentRecordsSubtitle => 'View all payment records';

  @override
  String get walletPayoutManagementSubtitle => 'Manage your payouts';

  @override
  String get paymentLoadingForm => 'Loading payment form...';

  @override
  String get paymentPreparing => 'Preparing...';

  @override
  String get paymentSuccess => 'Payment Successful';

  @override
  String get paymentSuccessMessage =>
      'Your payment has been successfully processed, the task will start soon.';

  @override
  String get paymentError => 'Payment Error';

  @override
  String get paymentTaskInfo => 'Task Information';

  @override
  String get paymentTaskTitle => 'Task Title';

  @override
  String get paymentApplicant => 'Applicant';

  @override
  String get paymentTip => 'Tip';

  @override
  String get paymentConfirmPayment => 'Confirm Payment';

  @override
  String get paymentPreparingPayment => 'Preparing payment...';

  @override
  String get paymentPayment => 'Payment';

  @override
  String get paymentCancel => 'Cancel';

  @override
  String get paymentRetry => 'Retry';

  @override
  String get paymentRetryPayment => 'Retry Payment';

  @override
  String get paymentCoupons => 'Coupons';

  @override
  String get paymentCouponDiscount => 'Coupon Discount';

  @override
  String get paymentNoAvailableCoupons => 'No Available Coupons';

  @override
  String get paymentDoNotUseCoupon => 'Don\'t use coupon';

  @override
  String get paymentTimeoutOrRefreshHint =>
      'If you have already paid, close this page and refresh; otherwise please try again';

  @override
  String get paymentConfirmingDoNotRepeat =>
      'Confirming payment. Please wait and do not pay again.';

  @override
  String get paymentWaitingConfirmHint =>
      'If you have already paid, we will confirm automatically. Please wait (within about 5 minutes).';

  @override
  String get paymentTotalAmount => 'Total Amount';

  @override
  String get paymentFinalPayment => 'Final Payment';

  @override
  String get paymentMixed => 'Mixed';

  @override
  String get paymentSelectMethod => 'Select Payment Method';

  @override
  String get paymentPayWithApplePay => 'Pay with Apple Pay';

  @override
  String get paymentPayWithGooglePay => 'Pay with Google Pay';

  @override
  String get paymentPayWithWechatPay => 'Pay with WeChat Pay';

  @override
  String get paymentPayWithAlipay => 'Pay with Alipay';

  @override
  String get shareWechat => 'WeChat';

  @override
  String get shareWechatMoments => 'Moments';

  @override
  String get shareQq => 'QQ';

  @override
  String get shareQzone => 'QQ Zone';

  @override
  String get shareWeibo => 'Weibo';

  @override
  String get shareSms => 'SMS';

  @override
  String get shareCopyLink => 'Copy Link';

  @override
  String get shareGenerateImage => 'Generate Image';

  @override
  String get shareShareTo => 'Share To';

  @override
  String get shareGeneratingImage => 'Generating share image...';

  @override
  String get shareImage => 'Share Image';

  @override
  String get shareShareImage => 'Share Image';

  @override
  String get shareSaveToPhotos => 'Save to Photos';

  @override
  String get translationTranslating => 'Translating...';

  @override
  String get translationTranslate => 'Translate';

  @override
  String get translationShowTranslation => 'Show Translation';

  @override
  String get translationShowOriginal => 'Show Original';

  @override
  String get settingsNotifications => 'Receive push notifications';

  @override
  String get settingsAllowNotifications => 'Allow Notifications';

  @override
  String get settingsSuccessSound => 'Success Sound';

  @override
  String get settingsSuccessSoundDescription =>
      'Play a short sound when an action succeeds';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsThemeMode => 'Theme Mode';

  @override
  String get settingsMembership => 'Membership';

  @override
  String get settingsVipMembership => 'VIP Membership';

  @override
  String get settingsHelpSupport => 'Help & Support';

  @override
  String get settingsFaq => 'FAQ';

  @override
  String get settingsContactSupport => 'Contact Support';

  @override
  String get settingsLegal => 'Legal Information';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsAppName => 'App Name';

  @override
  String get settingsPaymentAccount => 'Payment Account';

  @override
  String get settingsSetupPaymentAccount => 'Setup Payment Account';

  @override
  String get settingsAccount => 'Account';

  @override
  String get settingsUserId => 'User ID';

  @override
  String get settingsDeleteAccount => 'Delete Account';

  @override
  String get settingsDeleteAccountMessage =>
      'Are you sure you want to delete your account? This action cannot be undone. All your data will be permanently deleted.';

  @override
  String get themeSystem => 'Follow System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get walletPayoutManagement => 'Payout Management';

  @override
  String get walletPaymentRecords => 'Payment Records';

  @override
  String get myTasksLoadingCompleted => 'Loading completed tasks...';

  @override
  String get myTasksNetworkUnavailable => 'Network Unavailable';

  @override
  String get myTasksCheckNetwork =>
      'Please check your network connection and try again';

  @override
  String get myTasksNoPendingApplications => 'No Pending Applications';

  @override
  String get myTasksNoPendingApplicationsMessage =>
      'You have no pending application records yet';

  @override
  String get myTasksPending => 'Pending';

  @override
  String get myTasksApplicationMessage => 'Application Message';

  @override
  String get myTasksViewDetails => 'View Details';

  @override
  String get myTasksTabAll => 'All';

  @override
  String get myTasksTabPosted => 'Posted';

  @override
  String get myTasksTabTaken => 'Taken';

  @override
  String get myTasksTabPending => 'Pending';

  @override
  String get myTasksTabInProgress => 'In Progress';

  @override
  String get myTasksTabCompleted => 'Completed';

  @override
  String get myTasksTabCancelled => 'Cancelled';

  @override
  String get myTasksEmptyAll => 'You haven\'t posted or accepted any tasks yet';

  @override
  String get myTasksEmptyPosted => 'You haven\'t posted any tasks yet';

  @override
  String get myTasksEmptyTaken => 'You haven\'t accepted any tasks yet';

  @override
  String get myTasksEmptyInProgress => 'You have no in-progress tasks yet';

  @override
  String get myTasksEmptyPending =>
      'You have no pending application records yet';

  @override
  String get myTasksEmptyCompleted => 'You have no completed tasks yet';

  @override
  String get myTasksEmptyCancelled => 'You have no cancelled tasks yet';

  @override
  String get myTasksRolePoster => 'Poster';

  @override
  String get myTasksRoleTaker => 'Taker';

  @override
  String get myTasksRoleExpert => 'Expert';

  @override
  String get myTasksRoleApplicant => 'Applicant';

  @override
  String get myTasksRoleParticipant => 'Participant';

  @override
  String get myTasksRoleUser => 'User';

  @override
  String get myTasksRoleOrganizer => 'Organizer';

  @override
  String get myTasksRoleUnknown => 'Unknown';

  @override
  String get taskSourceNormal => 'Normal Task';

  @override
  String get taskSourceFleaMarket => 'Flea Market';

  @override
  String get taskSourceExpertService => 'Expert Service';

  @override
  String get taskSourceExpertActivity => 'Expert Activity';

  @override
  String get taskStatusOpen => 'Open';

  @override
  String get taskStatusInProgress => 'In Progress';

  @override
  String get taskStatusCompleted => 'Completed';

  @override
  String get taskStatusCancelled => 'Cancelled';

  @override
  String get taskStatusPendingConfirmation => 'Pending Confirmation';

  @override
  String get taskStatusPendingPayment => 'Pending Payment';

  @override
  String get taskStatusDisputed => 'Disputed';

  @override
  String get myPostsTitle => 'My Posts';

  @override
  String get taskLocationAddress => 'Task Address';

  @override
  String get taskLocationCoordinates => 'Coordinates';

  @override
  String get taskLocationAppleMaps => 'Apple Maps';

  @override
  String get taskLocationMyLocation => 'My Location';

  @override
  String get taskLocationLoadingAddress => 'Loading address...';

  @override
  String get taskLocationDetailAddress => 'Detail Address';

  @override
  String get fleaMarketPublishItem => 'List Item';

  @override
  String get fleaMarketConfirmPurchase => 'Confirm Purchase';

  @override
  String get fleaMarketBidPurchase => 'Bid Purchase';

  @override
  String get fleaMarketPriceAndTransaction => 'Price & Transaction';

  @override
  String fleaMarketAutoRemovalDays(int param1) {
    return 'Auto removal in $param1 days';
  }

  @override
  String get fleaMarketAutoRemovalSoon => 'Item will be removed soon';

  @override
  String get fleaMarketLoading => 'Loading...';

  @override
  String get fleaMarketLoadFailed => 'Failed to load item information';

  @override
  String get fleaMarketProductDetail => 'Product Detail';

  @override
  String get fleaMarketNoDescription => 'Seller has not written anything~';

  @override
  String get fleaMarketActiveSeller => 'Active Seller';

  @override
  String get fleaMarketContactSeller => 'Contact';

  @override
  String get fleaMarketEditItem => 'Edit Item';

  @override
  String get fleaMarketFavorite => 'Favorite';

  @override
  String get fleaMarketNegotiate => 'Negotiate';

  @override
  String get fleaMarketBuyNow => 'Buy Now';

  @override
  String get fleaMarketYourBid => 'Your Bid';

  @override
  String get fleaMarketMessageToSeller => 'Message to Seller (Optional)';

  @override
  String get fleaMarketMessagePlaceholder =>
      'e.g., Hope to meet in person, can you include shipping, etc...';

  @override
  String get fleaMarketEnterAmount => 'Enter amount';

  @override
  String get fleaMarketNegotiateRequestSent => 'Negotiation Request Sent';

  @override
  String get fleaMarketNegotiateRequestSentMessage =>
      'You have submitted a purchase request, please wait for the seller to process';

  @override
  String get fleaMarketNegotiateRequestFailed =>
      'Failed to send negotiation request. Please try again.';

  @override
  String get fleaMarketNegotiatePriceInvalid =>
      'Please enter a valid negotiation price.';

  @override
  String get fleaMarketNegotiatePriceTooHigh =>
      'Negotiation price cannot be higher than the original price.';

  @override
  String get fleaMarketNegotiatePriceTooLow =>
      'Negotiation price must be greater than 0.';

  @override
  String get taskPreferencesTitle => 'Task Preferences';

  @override
  String get taskPreferencesPreferredTypes => 'Preferred Task Types';

  @override
  String get taskPreferencesPreferredTypesDescription =>
      'Select task types you are interested in. The system will prioritize recommending these types of tasks';

  @override
  String get taskPreferencesPreferredLocations => 'Preferred Locations';

  @override
  String get taskPreferencesPreferredLocationsDescription =>
      'Select the geographic locations where you want to receive tasks';

  @override
  String get taskPreferencesPreferredLevels => 'Preferred Task Levels';

  @override
  String get taskPreferencesPreferredLevelsDescription =>
      'Select task levels you are interested in';

  @override
  String get taskPreferencesMinDeadline => 'Minimum Deadline';

  @override
  String get taskPreferencesMinDeadlineDescription =>
      'Set the minimum number of days required for task deadlines. The system will only recommend tasks that meet this condition';

  @override
  String get taskPreferencesDays => 'days';

  @override
  String get taskPreferencesDaysRange => '(At least 1 day, at most 30 days)';

  @override
  String get taskPreferencesSave => 'Save Preferences';

  @override
  String get taskLocationSearchCity => 'Search or enter city name';

  @override
  String get forumCreatePostTitle => 'Create Post';

  @override
  String get forumCreatePostBasicInfo => 'Basic Information';

  @override
  String get forumCreatePostPostTitle => 'Post Title';

  @override
  String get forumCreatePostPostTitlePlaceholder =>
      'Give your post an attractive title';

  @override
  String get forumCreatePostPostContent => 'Post Content';

  @override
  String get forumCreatePostContentPlaceholder =>
      'Share your insights, experiences, or ask questions. Be friendly and help each other grow...';

  @override
  String get forumCreatePostPublishing => 'Publishing...';

  @override
  String get forumCreatePostPublishNow => 'Publish Now';

  @override
  String get forumCreatePostImages => 'Images';

  @override
  String get forumCreatePostAddImage => 'Add image';

  @override
  String get fleaMarketCreatePublishing => 'Publishing...';

  @override
  String get fleaMarketCreatePublishNow => 'Publish Item Now';

  @override
  String get fleaMarketCreateSearchLocation =>
      'Search location or enter Online';

  @override
  String get taskExpertTitle => 'Task Experts';

  @override
  String get taskExpertWhatIs => 'What are Task Experts?';

  @override
  String get taskExpertWhatIsContent =>
      'Task Experts are platform-certified professional service providers with rich experience and good reputation. After becoming a Task Expert, your services will get more exposure and attract more customers.';

  @override
  String get taskExpertMoreExposure => 'More Exposure';

  @override
  String get taskExpertMoreExposureDesc =>
      'Your services will be prioritized and get more user attention';

  @override
  String get taskExpertExclusiveBadge => 'Exclusive Badge';

  @override
  String get taskExpertExclusiveBadgeDesc =>
      'Display expert certification badge to enhance your professional image';

  @override
  String get taskExpertMoreOrders => 'More Orders';

  @override
  String get taskExpertMoreOrdersDesc =>
      'Get more task applications and increase income opportunities';

  @override
  String get taskExpertPlatformSupport => 'Platform Support';

  @override
  String get taskExpertPlatformSupportDesc =>
      'Enjoy professional support and resources provided by the platform';

  @override
  String get taskExpertFillApplication => 'Fill Application Information';

  @override
  String get taskExpertFillApplicationDesc =>
      'Introduce your professional skills and experience';

  @override
  String get taskExpertSubmitReview => 'Submit for Review';

  @override
  String get taskExpertSubmitReviewDesc =>
      'Platform will complete the review within 3-5 business days';

  @override
  String get taskExpertStartService => 'Start Service';

  @override
  String get taskExpertStartServiceDesc =>
      'After approval, you can publish services and start accepting orders';

  @override
  String get taskExpertApplyTitle => 'Apply to Become Expert';

  @override
  String get taskExpertApplicationSubmittedMessage =>
      'Your application has been submitted. We will complete the review within 3-5 business days.';

  @override
  String get taskExpertNoExperts => 'No Task Experts';

  @override
  String get taskExpertNoExpertsMessage => 'No task experts yet, stay tuned...';

  @override
  String get taskExpertNoExpertsSearchMessage => 'No related experts found';

  @override
  String get taskExpertSearchPrompt => 'Search task experts';

  @override
  String get taskExpertNoFavorites => 'No Favorites';

  @override
  String get taskExpertNoActivities => 'No Activities';

  @override
  String get taskExpertNoFavoritesMessage =>
      'You have not favorited any activities';

  @override
  String get taskExpertNoAppliedMessage =>
      'You have not applied for any activities';

  @override
  String get taskExpertNoActivitiesMessage =>
      'You have not applied or favorited any activities';

  @override
  String taskExpertRelatedActivitiesAvailable(int count) {
    return '$count related activities available';
  }

  @override
  String get taskExpertRelatedActivitiesSection =>
      'Expert\'s Related Activities';

  @override
  String get taskExpertExpertiseAreas => 'Expertise Areas';

  @override
  String get taskExpertFeaturedSkills => 'Featured Skills';

  @override
  String get taskExpertAchievements => 'Achievements';

  @override
  String get taskExpertResponseTime => 'Response Time';

  @override
  String get taskExpertReviews => 'Reviews';

  @override
  String get taskExpertNoReviews => 'No reviews yet';

  @override
  String taskExpertReviewsCount(int param1) {
    return '$param1 reviews';
  }

  @override
  String get taskExpertNoExpertiseAreas => 'No expertise areas';

  @override
  String get taskExpertNoFeaturedSkills => 'No featured skills';

  @override
  String get taskExpertNoAchievements => 'No achievements';

  @override
  String get leaderboardApplyTitle => 'Apply for New Leaderboard';

  @override
  String get leaderboardInfo => 'Leaderboard Information';

  @override
  String get leaderboardName => 'Leaderboard Name';

  @override
  String get leaderboardRegion => 'Region';

  @override
  String get leaderboardDescription => 'Description';

  @override
  String get leaderboardReason => 'Application Reason';

  @override
  String get leaderboardReasonTitle => 'Why create this leaderboard?';

  @override
  String get leaderboardReasonPlaceholder =>
      'Explain to the administrator the necessity of creating this leaderboard, which helps speed up the review process...';

  @override
  String get leaderboardCoverImage => 'Cover Image (Optional)';

  @override
  String get leaderboardAddCoverImage => 'Add Cover Image';

  @override
  String get leaderboardOptional => 'Optional';

  @override
  String get leaderboardChangeImage => 'Change';

  @override
  String get leaderboardLoading => 'Loading...';

  @override
  String get notificationNotifications => 'Notifications';

  @override
  String get notificationNoTaskChat => 'No task chats';

  @override
  String get notificationNoTaskChatMessage =>
      'No task-related chat records yet';

  @override
  String get notificationNoMessages => 'No messages yet';

  @override
  String get notificationStartConversation => 'Start a conversation!';

  @override
  String get notificationNewMessage => 'New messages';

  @override
  String get notificationSending => 'Sending...';

  @override
  String get notificationViewDetails => 'View Details';

  @override
  String get notificationImage => 'Image';

  @override
  String get notificationTaskDetail => 'Task Detail';

  @override
  String get notificationDetailAddress => 'Detail Address';

  @override
  String get notificationTaskEnded => 'Task has ended';

  @override
  String get notificationTaskCompletedCannotSend =>
      'Task completed, cannot send messages';

  @override
  String get notificationTaskCancelledCannotSend =>
      'Task cancelled, cannot send messages';

  @override
  String get notificationTaskPendingCannotSend =>
      'Task pending confirmation, message sending paused';

  @override
  String get notificationSystemNotification => 'System Notification';

  @override
  String get notificationTitleTaskApplication => 'New Task Application';

  @override
  String get notificationTitleApplicationAccepted =>
      'Application Accepted - Payment Required';

  @override
  String get notificationTitleApplicationRejected => 'Application Rejected';

  @override
  String get notificationTitleApplicationWithdrawn => 'Application Withdrawn';

  @override
  String get notificationTitleTaskCompleted => 'Task Completed';

  @override
  String get notificationTitleTaskConfirmed => 'Reward Issued';

  @override
  String get notificationTitleTaskCancelled => 'Task Cancelled';

  @override
  String get notificationTitleTaskAutoCancelled => 'Task Auto-Cancelled';

  @override
  String get notificationTitleApplicationMessage => 'New Message';

  @override
  String get notificationTitleNegotiationOffer => 'New Price Offer';

  @override
  String get notificationTitleNegotiationRejected => 'Negotiation Rejected';

  @override
  String get notificationTitleTaskApproved => 'Task Application Approved';

  @override
  String get notificationTitleTaskRewardPaid => 'Task Reward Paid';

  @override
  String get notificationTitleTaskApprovedWithPayment =>
      'Task Application Approved - Payment Required';

  @override
  String get notificationTitleAnnouncement => 'Announcement';

  @override
  String get notificationTitleCustomerService => 'Customer Service';

  @override
  String get notificationTitleUnknown => 'Notification';

  @override
  String notificationContentTaskApplication(String applicant_name,
      String task_title, String application_message, String price_info) {
    return '$applicant_name applied for task「$task_title」\\nApplication message: $application_message\\nNegotiated price: $price_info';
  }

  @override
  String notificationContentApplicationAccepted(
      String task_title, String payment_expires_info) {
    return 'The applicant has accepted your negotiation offer for task「$task_title」. Please complete the payment.$payment_expires_info';
  }

  @override
  String notificationContentApplicationRejected(String task_title) {
    return 'Your task application has been rejected: $task_title';
  }

  @override
  String notificationContentApplicationWithdrawn(String task_title) {
    return 'An applicant has withdrawn their application for task「$task_title」';
  }

  @override
  String notificationContentTaskCompleted(
      String taker_name, String task_title) {
    return '$taker_name has marked task「$task_title」as completed';
  }

  @override
  String notificationContentTaskConfirmed(String task_title) {
    return 'Task completed and confirmed! Reward for「$task_title」has been issued';
  }

  @override
  String notificationContentTaskCancelled(String task_title) {
    return 'Your task「$task_title」has been cancelled';
  }

  @override
  String notificationContentTaskAutoCancelled(String task_title) {
    return 'Your task「$task_title」has been automatically cancelled due to exceeding the deadline';
  }

  @override
  String notificationContentApplicationMessage(
      String task_title, String message) {
    return 'The publisher of task「$task_title」sent you a message: $message';
  }

  @override
  String notificationContentNegotiationOffer(String task_title, String message,
      String negotiated_price, String currency) {
    return 'The publisher of task「$task_title」proposed a negotiation\nMessage: $message\nNegotiated price: £$negotiated_price $currency';
  }

  @override
  String notificationContentNegotiationRejected(String task_title) {
    return 'The applicant has rejected your negotiation offer for task「$task_title」';
  }

  @override
  String notificationContentTaskApproved(String task_title) {
    return 'Your application for task「$task_title」has been approved';
  }

  @override
  String notificationContentTaskRewardPaid(String task_title) {
    return 'Reward for task「$task_title」has been paid';
  }

  @override
  String notificationContentTaskApprovedWithPayment(
      String task_title, String payment_expires_info) {
    return 'Your task application has been approved! Task: $task_title$payment_expires_info';
  }

  @override
  String notificationContentAnnouncement(String message) {
    return '$message';
  }

  @override
  String notificationContentCustomerService(String message) {
    return '$message';
  }

  @override
  String notificationContentUnknown(String message) {
    return '$message';
  }

  @override
  String get notificationCustomerService => 'Customer Service';

  @override
  String get notificationContactService => 'Contact Service';

  @override
  String get notificationTaskChat => 'Task Chat';

  @override
  String get notificationTaskChatList => 'All Task Chat List';

  @override
  String get notificationPoster => 'Poster';

  @override
  String get notificationTaker => 'Taker';

  @override
  String get notificationExpert => 'Expert';

  @override
  String get notificationParticipant => 'Participant';

  @override
  String get notificationSystem => 'System';

  @override
  String get notificationSystemMessage => 'System Message';

  @override
  String get notificationTaskChats => 'Task Chats';

  @override
  String get commonLoadMore => 'Load More';

  @override
  String get commonTagSeparator => ', ';

  @override
  String get commonCopy => 'Copy';

  @override
  String commonCopied(String param1) {
    return 'Copied: $param1';
  }

  @override
  String get commonTap => 'Tap';

  @override
  String get commonLongPressToCopy => 'Long press to copy';

  @override
  String get errorOperationFailed => 'Operation Failed';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingWelcomeTitle => 'Welcome to Link²Ur';

  @override
  String get onboardingWelcomeSubtitle => 'Campus Mutual Aid Platform';

  @override
  String get onboardingWelcomeDescription =>
      'Publish tasks, accept tasks, buy and sell second-hand goods, everything is in your hands';

  @override
  String get onboardingPublishTaskTitle => 'Publish Tasks';

  @override
  String get onboardingPublishTaskSubtitle => 'Easily find help';

  @override
  String get onboardingPublishTaskDescription =>
      'Need help? Publish a task and let capable users help you complete it';

  @override
  String get onboardingAcceptTaskTitle => 'Accept Tasks';

  @override
  String get onboardingAcceptTaskSubtitle => 'Earn extra income';

  @override
  String get onboardingAcceptTaskDescription =>
      'Browse tasks, accept interesting tasks, and earn rewards after completing them';

  @override
  String get onboardingSecurePaymentTitle => 'Secure Payment';

  @override
  String get onboardingSecurePaymentSubtitle =>
      'Platform guarantees transaction security';

  @override
  String get onboardingSecurePaymentDescription =>
      'Use Stripe secure payment, automatic transfer after task completion, protecting both parties\' rights';

  @override
  String get onboardingCommunityTitle => 'Community Interaction';

  @override
  String get onboardingCommunitySubtitle => 'Connect your world';

  @override
  String get onboardingCommunityDescription =>
      'Participate in community discussions, view leaderboards, buy and sell second-hand goods, enrich your campus life';

  @override
  String get onboardingPersonalizationTitle => 'Personalization Settings';

  @override
  String get onboardingPersonalizationSubtitle =>
      'Help us recommend more suitable content for you';

  @override
  String get onboardingPreferredCity => 'Preferred City';

  @override
  String get onboardingUseCurrentLocation => 'Use Current Location';

  @override
  String get onboardingPreferredTaskTypes => 'Interested Task Types';

  @override
  String get onboardingPreferredTaskTypesOptional =>
      'Interested Task Types (Optional)';

  @override
  String get onboardingEnableNotifications => 'Enable Notifications';

  @override
  String get onboardingEnableNotificationsDescription =>
      'Receive task status updates and message reminders in time';

  @override
  String get onboardingGetStarted => 'Get Started';

  @override
  String get onboardingPrevious => 'Previous';

  @override
  String get spotlightTask => 'Task';

  @override
  String get spotlightTasks => 'Tasks';

  @override
  String get spotlightExpert => 'Task Expert';

  @override
  String get spotlightQuickAction => 'Quick Action';

  @override
  String get shortcutsPublishTask => 'Publish Task';

  @override
  String get shortcutsPublishTaskDescription => 'Quickly publish a new task';

  @override
  String get shortcutsViewMyTasks => 'View My Tasks';

  @override
  String get shortcutsViewMyTasksDescription =>
      'View tasks I published and accepted';

  @override
  String get shortcutsViewMessages => 'View Messages';

  @override
  String get shortcutsViewMessagesDescription =>
      'View unread messages and notifications';

  @override
  String get shortcutsSearchTasks => 'Search Tasks';

  @override
  String get shortcutsSearchTasksDescription => 'Search for tasks';

  @override
  String get shortcutsViewFleaMarket => 'View Flea Market';

  @override
  String get shortcutsViewFleaMarketDescription =>
      'Browse and publish second-hand goods';

  @override
  String get shortcutsViewForum => 'View Forum';

  @override
  String get shortcutsViewForumDescription =>
      'Participate in community discussions';

  @override
  String get profileInProgress => 'In Progress';

  @override
  String get profileCompleted => 'Completed';

  @override
  String get profileCreditScore => 'Credit Score';

  @override
  String get profileMyContent => 'My Content';

  @override
  String get profileSystemAndVerification => 'System & Verification';

  @override
  String get profileMyTasksSubtitleText =>
      'Manage tasks I published and accepted';

  @override
  String get profileMyPostsSubtitleText =>
      'Second-hand item transaction records';

  @override
  String get profileMyForumPosts => 'My Posts';

  @override
  String get profileMyForumPostsSubtitle =>
      'View discussions I posted in the forum';

  @override
  String get profileMyWalletSubtitleText => 'Balance, recharge and withdrawal';

  @override
  String get profilePointsCouponsSubtitleText => 'Points details and coupons';

  @override
  String get profileStudentVerificationSubtitleText =>
      'Get student-exclusive verification badge';

  @override
  String get profileActivitySubtitleText =>
      'View offline activities I participated in';

  @override
  String get profileTaskPreferences => 'Task Preferences';

  @override
  String get profileTaskPreferencesSubtitle =>
      'Personalize recommended content';

  @override
  String get profileMyApplicationsSubtitleText =>
      'Expert/Service provider application status';

  @override
  String get profileSettingsSubtitleText => 'Profile, password and security';

  @override
  String get profilePaymentAccount => 'Payout Account';

  @override
  String get profilePaymentAccountSubtitle =>
      'Set up payout account to receive task rewards';

  @override
  String get profileNoContactInfo => 'No contact information';

  @override
  String get profileUserProfile => 'User Profile';

  @override
  String get profilePostedTasks => 'Posted';

  @override
  String get profileTakenTasks => 'Taken Tasks';

  @override
  String get profileCompletedTasks => 'Completed Tasks';

  @override
  String get myItemsSelling => 'Selling';

  @override
  String get myItemsPurchased => 'Purchased';

  @override
  String get myItemsFavorites => 'Favorites';

  @override
  String get myItemsSold => 'Sold';

  @override
  String get myItemsEmptySelling => 'No Items for Sale';

  @override
  String get myItemsEmptyPurchased => 'No Purchase Records';

  @override
  String get myItemsEmptyFavorites => 'No Favorites';

  @override
  String get myItemsEmptySold => 'No Sold Items';

  @override
  String get myItemsEmptySellingMessage =>
      'You haven\'t published any second-hand items yet';

  @override
  String get myItemsEmptyPurchasedMessage =>
      'You haven\'t purchased any items yet';

  @override
  String get myItemsEmptyFavoritesMessage =>
      'You haven\'t favorited any items yet';

  @override
  String get myItemsEmptySoldMessage =>
      'You haven\'t successfully sold any items yet';

  @override
  String get myItemsStatusSelling => 'For Sale';

  @override
  String get myItemsStatusPurchased => 'Purchased';

  @override
  String get myItemsStatusSold => 'Sold';

  @override
  String get forumPinned => 'Pinned';

  @override
  String get forumFeatured => 'Featured';

  @override
  String get forumWriteReplyPlaceholder => 'Write your reply...';

  @override
  String get forumViewThisPost => 'Check out this post';

  @override
  String get forumBrowse => 'Views';

  @override
  String get forumRepliesCount => 'replies';

  @override
  String get fleaMarketStatusActive => 'For Sale';

  @override
  String get fleaMarketStatusDelisted => 'Delisted';

  @override
  String get fleaMarketRefreshing => 'Refreshing...';

  @override
  String get fleaMarketRefresh => 'Refresh';

  @override
  String get fleaMarketConfirm => 'Confirm';

  @override
  String get fleaMarketSubmit => 'Submit';

  @override
  String get fleaMarketViewItem => 'View this item';

  @override
  String get fleaMarketSaving => 'Saving...';

  @override
  String get fleaMarketSaveChanges => 'Save Changes';

  @override
  String get fleaMarketEditItemTitle => 'Edit Item';

  @override
  String get fleaMarketCategoryElectronics => 'Electronics';

  @override
  String get fleaMarketCategoryClothing => 'Clothing & Bags';

  @override
  String get fleaMarketCategoryFurniture => 'Furniture & Appliances';

  @override
  String get fleaMarketCategoryBooks => 'Books & Textbooks';

  @override
  String get fleaMarketCategorySports => 'Sports & Outdoor';

  @override
  String get fleaMarketCategoryBeauty => 'Beauty & Skincare';

  @override
  String get fleaMarketCategoryOther => 'Other';

  @override
  String get fleaMarketPartialUploadFailed =>
      'Some images failed to upload, please try again';

  @override
  String get fleaMarketUploadTimeout =>
      'Image upload timed out, please try again';

  @override
  String get fleaMarketPickImageBusy =>
      'Image picker is busy, please try again later';

  @override
  String get fleaMarketFillRequiredFields =>
      'Please fill in all required fields';

  @override
  String fleaMarketPurchaseRequestsCount(int param1) {
    return 'Purchase Requests ($param1)';
  }

  @override
  String get fleaMarketNoPurchaseRequests => 'No Purchase Requests';

  @override
  String get fleaMarketWaitingSellerConfirm =>
      'Waiting for seller confirmation';

  @override
  String fleaMarketNegotiateAmountFormat(double param1) {
    return 'Negotiated price: £$param1';
  }

  @override
  String get fleaMarketContinuePayment => 'Continue Payment';

  @override
  String get fleaMarketPreparing => 'Preparing...';

  @override
  String get fleaMarketSendingNegotiateRequest =>
      'Sending negotiation request...';

  @override
  String get fleaMarketProcessingPurchase => 'Processing purchase...';

  @override
  String get fleaMarketNegotiateAmountLabel => 'Negotiated price:';

  @override
  String get fleaMarketSellerNegotiateLabel => 'Seller counter offer:';

  @override
  String get fleaMarketRejectPurchaseConfirmTitle => 'Reject Purchase Request';

  @override
  String get fleaMarketRejectPurchaseConfirmMessage =>
      'Are you sure you want to reject this purchase request?';

  @override
  String get fleaMarketRequestStatusPending => 'Pending';

  @override
  String get fleaMarketRequestStatusSellerNegotiating => 'Seller Negotiating';

  @override
  String get fleaMarketRequestStatusAccepted => 'Accepted';

  @override
  String get fleaMarketRequestStatusRejected => 'Rejected';

  @override
  String get fleaMarketAcceptCounterOffer => 'Accept';

  @override
  String get fleaMarketRejectCounterOffer => 'Decline';

  @override
  String fleaMarketCounterOfferReceived(String price) {
    return 'Seller counter-offered £$price';
  }

  @override
  String get fleaMarketAcceptCounterOfferConfirmTitle => 'Accept Counter Offer';

  @override
  String fleaMarketAcceptCounterOfferConfirmMessage(String price) {
    return 'Are you sure you want to accept the seller\'s counter offer of £$price?';
  }

  @override
  String get fleaMarketRejectCounterOfferConfirmTitle =>
      'Decline Counter Offer';

  @override
  String get fleaMarketRejectCounterOfferConfirmMessage =>
      'Are you sure you want to decline the seller\'s counter offer?';

  @override
  String get fleaMarketCounterOfferAccepted => 'Counter offer accepted';

  @override
  String get fleaMarketCounterOfferRejected => 'Counter offer declined';

  @override
  String get applePayNotSupported => 'Your device does not support Apple Pay';

  @override
  String get applePayUseOtherMethod => 'Please use another payment method';

  @override
  String get applePayTitle => 'Apple Pay';

  @override
  String get applePayNotConfigured => 'Apple Pay is not configured';

  @override
  String get applePayPaymentInfoNotReady => 'Payment info not ready';

  @override
  String get applePayTaskPaymentFallback => 'Link²Ur Task Payment';

  @override
  String get applePayUnableToCreateForm => 'Unable to create Apple Pay form';

  @override
  String get applePayUnableToGetPaymentInfo => 'Unable to get payment info';

  @override
  String get chatEvidenceFile => 'Evidence file';

  @override
  String get paymentUnknownError => 'Unknown error';

  @override
  String get paymentAmount => 'Payment Amount';

  @override
  String get paymentSuccessCompleted =>
      'Your payment has been successfully completed';

  @override
  String get paymentFailed => 'Payment Failed';

  @override
  String get wechatPayTitle => 'WeChat Pay';

  @override
  String get wechatPayLoading => 'Loading payment page...';

  @override
  String get wechatPayLoadFailed => 'Load Failed';

  @override
  String get wechatPayCancelConfirmTitle => 'Cancel Payment?';

  @override
  String get wechatPayContinuePay => 'Continue Payment';

  @override
  String get wechatPayCancelPay => 'Cancel Payment';

  @override
  String get wechatPayCancelWarning =>
      'You will need to initiate payment again if you cancel';

  @override
  String get wechatPayInvalidLink => 'Invalid payment link';

  @override
  String get forumMyPosts => 'My Posts';

  @override
  String get forumMyPostsPosted => 'Posted';

  @override
  String get forumMyPostsFavorited => 'Favorited';

  @override
  String get forumMyPostsLiked => 'Liked';

  @override
  String get forumMyPostsEmptyPosted => 'You haven\'t posted any posts yet';

  @override
  String get forumMyPostsEmptyFavorited =>
      'You haven\'t favorited any posts yet';

  @override
  String get forumMyPostsEmptyLiked => 'You haven\'t liked any posts yet';

  @override
  String get forumLoadFailed => 'Load Failed';

  @override
  String get forumRetry => 'Retry';

  @override
  String get forumNoCategories => 'No Categories';

  @override
  String get forumCategoriesLoading => 'Loading forum categories...';

  @override
  String get forumRequestNewCategory => 'Request New Category';

  @override
  String get forumRequestSubmitted => 'Request Submitted';

  @override
  String get forumRequestSubmittedMessage =>
      'Your request has been successfully submitted. The administrator will notify you of the result after review.';

  @override
  String get forumRequestInstructions => 'Request Instructions';

  @override
  String get forumRequestInstructionsText =>
      'Fill in the following information to request a new forum category. Your request will be reviewed by the administrator, and the category will be officially created after approval.';

  @override
  String get forumCategoryName => 'Category Name';

  @override
  String get forumCategoryNamePlaceholder => 'Please enter category name';

  @override
  String get forumCategoryDescription => 'Category Description';

  @override
  String get forumCategoryDescriptionPlaceholder =>
      'Please briefly describe the purpose and discussion topics of this category';

  @override
  String get forumCategoryIcon => 'Category Icon (Optional)';

  @override
  String get forumCategoryIconHint =>
      'You can enter an emoji as the category icon, for example: 💬, 📚, 🎮, etc.';

  @override
  String get forumCategoryIconExample => 'For example: 💬';

  @override
  String get forumCategoryIconEntered => '1 emoji entered';

  @override
  String get forumSubmitRequest => 'Submit Request';

  @override
  String get forumMyRequests => 'My Requests';

  @override
  String get forumRequestStatusAll => 'All';

  @override
  String get forumRequestStatusPending => 'Pending';

  @override
  String get forumRequestStatusApproved => 'Approved';

  @override
  String get forumRequestStatusRejected => 'Rejected';

  @override
  String get forumNoRequests => 'No Requests';

  @override
  String get forumNoRequestsMessage =>
      'You haven\'t submitted any category requests yet.';

  @override
  String get forumNoRequestsFiltered => 'No requests found for this status.';

  @override
  String get forumReviewComment => 'Review Comment';

  @override
  String get forumReviewTime => 'Review Time';

  @override
  String get forumRequestTime => 'Request Time';

  @override
  String get forumRequestNameRequired => 'Please enter category name';

  @override
  String forumRequestNameTooLong(int param1) {
    return 'Category name cannot exceed $param1 characters';
  }

  @override
  String forumRequestDescriptionTooLong(int param1) {
    return 'Category description cannot exceed $param1 characters';
  }

  @override
  String forumRequestIconTooLong(int param1) {
    return 'Icon cannot exceed $param1 characters';
  }

  @override
  String get forumRequestSubmitFailed =>
      'Submission failed, please check if the input is correct';

  @override
  String get forumRequestLoginExpired => 'Login expired, please login again';

  @override
  String get activityWaitingExpertResponse => 'Waiting for Expert Response';

  @override
  String get activityContinuePayment => 'Continue Payment';

  @override
  String get serviceApplied => 'Applied';

  @override
  String get serviceWaitingExpertResponse => 'Waiting for Expert Response';

  @override
  String get serviceContinuePayment => 'Continue Payment';

  @override
  String get serviceUnderReview => 'Under Review';

  @override
  String get serviceApplyAgain => 'Apply Again';

  @override
  String get serviceInProgress => 'Service in Progress';

  @override
  String get taskDetailConfirmDeadline => 'Confirm deadline';

  @override
  String get taskDetailPlatformServiceFee => 'Platform service fee';

  @override
  String get taskDetailServiceFeeRate => 'Service fee rate';

  @override
  String get taskDetailServiceFeeAmount => 'Service fee';

  @override
  String taskDetailCountdownRemainingDays(int param1, int param2, int param3) {
    return '$param1 days $param2 hrs $param3 min remaining';
  }

  @override
  String taskDetailCountdownRemainingHours(int param1, int param2, int param3) {
    return '$param1 hrs $param2 min $param3 sec remaining';
  }

  @override
  String taskDetailCountdownRemainingMinutes(int param1, int param2) {
    return '$param1 min $param2 sec remaining';
  }

  @override
  String taskDetailCountdownRemainingSeconds(int param1) {
    return '$param1 sec remaining';
  }

  @override
  String get taskDetailTaskCompletedTitle => 'Task completed';

  @override
  String get taskDetailTaskCompletedUploadHint =>
      'You have completed this task. You may upload evidence images or add a text description (optional) for the poster to confirm.';

  @override
  String get taskDetailSectionTextOptional => 'Text description (optional)';

  @override
  String get taskDetailSectionEvidenceImagesOptional =>
      'Evidence images (optional)';

  @override
  String get taskDetailSectionEvidenceFilesOptional =>
      'Evidence files (optional)';

  @override
  String get taskDetailSectionCompletionEvidenceOptional =>
      'Completion evidence (optional)';

  @override
  String get taskDetailTextLimit500 =>
      'Text description must not exceed 500 characters';

  @override
  String get taskDetailImageLimit5mb5 => 'Max 5MB per image, up to 5 images';

  @override
  String get taskDetailAddImage => 'Add image';

  @override
  String get taskDetailUploadProgress => 'Upload progress';

  @override
  String taskDetailUploadingCount(int param1, int param2) {
    return 'Uploading $param1/$param2...';
  }

  @override
  String get taskDetailConfirmCompleteTaskButton => 'Confirm task complete';

  @override
  String get taskDetailConfirmTaskCompleteAlertTitle => 'Confirm task complete';

  @override
  String get taskDetailConfirmTaskCompleteAlertMessage =>
      'Are you sure this task is complete? It will be sent to the poster for confirmation.';

  @override
  String get taskDetailConfirmTaskCompleteTitle => 'Confirm task complete';

  @override
  String get taskDetailConfirmTaskCompleteHint =>
      'You have confirmed this task is complete. You may upload evidence images (optional), e.g. screenshots or acceptance records.';

  @override
  String get taskDetailConfirmCompleteButton => 'Confirm complete';

  @override
  String get taskDetailPleaseConfirmComplete => 'Please confirm task complete';

  @override
  String get taskDetailAutoConfirmSoon =>
      'Will auto-confirm soon. Please confirm now.';

  @override
  String get taskDetailConfirmNow => 'Confirm now';

  @override
  String get taskDetailWaitingPosterConfirm => 'Waiting for poster to confirm';

  @override
  String get taskDetailAutoConfirmOnExpiry => '(Will auto-confirm on expiry)';

  @override
  String get taskDetailDisputeDetail => 'Task dispute details';

  @override
  String get taskDetailDeadlineLabel => 'Deadline';

  @override
  String get taskDetailNoUploadableImages => 'No images to upload';

  @override
  String taskDetailImageSizeErrorFormat(int param1, double param2) {
    return 'Image $param1 is still too large after compression (${param2}MB). Please choose a smaller image.';
  }

  @override
  String taskDetailImageTooLargeSelectFormat(double param1) {
    return 'Image too large (${param1}MB). Please choose a smaller image.';
  }

  @override
  String get taskDetailMaxImages5 => 'Maximum 5 images allowed';

  @override
  String get taskDetailCompleteTaskNavTitle => 'Complete Task';

  @override
  String get taskDetailTaskCompletionEvidence => 'Task completion evidence';

  @override
  String get taskDetailImageConvertError => 'Unable to convert image data';

  @override
  String taskDetailImageProcessErrorFormat(int param1) {
    return 'Image $param1 could not be processed. Please choose again.';
  }

  @override
  String taskDetailCompletedCountFormat(int param1) {
    return '$param1 completed';
  }

  @override
  String get refundSubmitRebuttalEvidence => 'Submit rebuttal evidence';

  @override
  String get refundSubmitRebuttalNavTitle => 'Submit rebuttal';

  @override
  String get refundViewHistory => 'View history';

  @override
  String get refundViewHistoryRecords => 'View history records';

  @override
  String get refundWithdrawApplication => 'Withdraw refund application';

  @override
  String get refundWithdrawApplicationMessage =>
      'Are you sure you want to withdraw this refund application? This cannot be undone.';

  @override
  String get refundWithdrawing => 'Withdrawing...';

  @override
  String get refundWithdrawApply => 'Withdraw application';

  @override
  String get refundTaskIncompleteApplyRefund =>
      'Task incomplete (apply for refund)';

  @override
  String get refundHistory => 'Refund history';

  @override
  String refundReasonLabel(String param1) {
    return 'Refund reason: $param1';
  }

  @override
  String get refundTypeFull => 'Full refund';

  @override
  String get refundTypePartial => 'Partial refund';

  @override
  String refundAdminCommentLabel(String param1) {
    return 'Admin note: $param1';
  }

  @override
  String get refundTakerRebuttal => 'Taker rebuttal';

  @override
  String refundEvidenceFilesCount(int param1) {
    return '$param1 evidence file(s) uploaded';
  }

  @override
  String get refundNoHistory => 'No refund history yet';

  @override
  String get refundReasonTypeLabel => 'Reason type:';

  @override
  String get refundTypeLabel => 'Refund type:';

  @override
  String refundReviewTimeLabel(String param1) {
    return 'Review time: $param1';
  }

  @override
  String refundApplyTimeLabel(String param1) {
    return 'Application time: $param1';
  }

  @override
  String get refundApplyRefund => 'Apply for refund';

  @override
  String get refundApplyRefundHint =>
      'Please describe the refund reason in detail and upload evidence (e.g. screenshots, chat logs). An admin will review within 3-5 business days.';

  @override
  String get refundReasonTypeRequired => 'Refund reason type *';

  @override
  String get refundReasonTypePlaceholder => 'Select refund reason type';

  @override
  String get refundPartialAmountTooHigh =>
      'Partial refund amount cannot be greater than or equal to task amount. Please choose full refund.';

  @override
  String refundAmountExceedsTask(double param1) {
    return 'Refund amount cannot exceed task amount (£$param1)';
  }

  @override
  String get refundAmountMustBePositive =>
      'Refund amount must be a number greater than 0';

  @override
  String get refundRatioRange => 'Refund percentage must be between 0-100';

  @override
  String get refundReasonDetailRequired => 'Refund reason details *';

  @override
  String get refundReasonMinLength =>
      'Refund reason must be at least 10 characters';

  @override
  String get refundTypeRequired => 'Refund type *';

  @override
  String get refundAmountOrRatioRequired => 'Refund amount or ratio *';

  @override
  String get refundAmountPound => 'Refund amount (£)';

  @override
  String get refundRatioPercent => 'Refund ratio (%)';

  @override
  String refundTaskAmountFormat(double param1) {
    return 'Task amount: £$param1';
  }

  @override
  String refundRefundAmountFormat(double param1) {
    return 'Refund amount: £$param1';
  }

  @override
  String get refundSubmitRefundApplication => 'Submit refund application';

  @override
  String get refundNoDisputeRecords => 'No dispute records yet';

  @override
  String get refundRebuttalDescription => 'Rebuttal description';

  @override
  String get refundRebuttalMinLength =>
      'Rebuttal description must be at least 10 characters';

  @override
  String get refundUploadLimit5 => 'Up to 5 images or files, max 5MB each';

  @override
  String get refundSelectImage => 'Select image';

  @override
  String refundStatusLabel(String param1) {
    return 'Status: $param1';
  }

  @override
  String get refundRebuttalHint =>
      'Please describe the task completion and upload evidence (e.g. screenshots, files). Your rebuttal will help the admin make a fair decision.';

  @override
  String get refundHistorySheetTitle => 'Refund history';

  @override
  String get disputeActorPoster => 'Poster';

  @override
  String get disputeActorTaker => 'Taker';

  @override
  String get disputeActorAdmin => 'Admin';

  @override
  String get disputeNoRecords => 'No dispute records';

  @override
  String get disputeStatusPending => 'Pending Review';

  @override
  String get disputeStatusProcessing => 'Processing';

  @override
  String get disputeStatusApproved => 'Approved';

  @override
  String get disputeStatusRejected => 'Rejected';

  @override
  String get disputeStatusCompleted => 'Completed';

  @override
  String get disputeStatusCancelled => 'Cancelled';

  @override
  String get disputeStatusResolved => 'Resolved';

  @override
  String get disputeStatusDismissed => 'Dismissed';

  @override
  String get refundReasonCompletionTime => 'Unsatisfied with completion time';

  @override
  String get refundReasonNotCompleted => 'Taker did not complete at all';

  @override
  String get refundReasonQualityIssue => 'Quality issue';

  @override
  String get refundReasonOther => 'Other';

  @override
  String get refundStatusPending => 'Pending';

  @override
  String get refundStatusProcessing => 'Processing';

  @override
  String get refundStatusApproved => 'Approved';

  @override
  String get refundStatusRejected => 'Rejected';

  @override
  String get refundStatusCompleted => 'Completed';

  @override
  String get refundStatusCancelled => 'Cancelled';

  @override
  String get refundStatusUnknown => 'Unknown status';

  @override
  String get refundStatusPendingFull => 'Refund pending review';

  @override
  String get refundStatusProcessingFull => 'Refund processing';

  @override
  String get refundStatusApprovedFull => 'Refund approved';

  @override
  String get refundStatusRejectedFull => 'Refund rejected';

  @override
  String get refundStatusCompletedFull => 'Refund completed';

  @override
  String get refundStatusCancelledFull => 'Refund cancelled';

  @override
  String get refundDescPending =>
      'Your refund has been submitted. Admin will review within 3-5 business days.';

  @override
  String get refundDescProcessing => 'Refund is being processed. Please wait.';

  @override
  String refundDescApprovedAmount(String param1, double param2) {
    return 'Refund amount: £$param2$param1. Will be returned in 5-10 business days.';
  }

  @override
  String get refundDescApprovedGeneric =>
      'Will be returned to your original payment method in 5-10 business days.';

  @override
  String refundDescRejectedReason(String param1) {
    return 'Rejection reason: $param1';
  }

  @override
  String get refundDescRejectedGeneric => 'Refund has been rejected.';

  @override
  String refundDescCompletedAmount(String param1, double param2) {
    return 'Refund amount: £$param2$param1. Returned to your original payment method.';
  }

  @override
  String get refundDescCompletedGeneric =>
      'Refund returned to your original payment method.';

  @override
  String get refundDescCancelled => 'Refund cancelled.';

  @override
  String get commonUnknown => 'Unknown';

  @override
  String get commonOr => 'or';

  @override
  String get fleaMarketProductTitleHint => 'Enter product title';

  @override
  String get fleaMarketDescriptionHint => 'Describe your product in detail';

  @override
  String get fleaMarketPriceAndTrade => 'Price & Transaction';

  @override
  String get fleaMarketFillRequired => 'Please fill in all required fields';

  @override
  String get fleaMarketLocation => 'Transaction Location';

  @override
  String get taskPreferencesTypes => 'Preferred Task Types';

  @override
  String get taskPreferencesTypesDesc =>
      'Select the task types you are interested in';

  @override
  String get taskPreferencesLocations => 'Preferred Locations';

  @override
  String get taskPreferencesLocationsDesc =>
      'Select locations where you prefer to complete tasks';

  @override
  String get taskPreferencesLevels => 'Preferred Task Levels';

  @override
  String get taskPreferencesLevelsDesc =>
      'Select the task levels you want to receive';

  @override
  String get taskPreferencesMinDeadlineDesc =>
      'Only show tasks with deadline longer than the set days';

  @override
  String get vipPleaseSelect => 'Please Select a Plan';

  @override
  String get commonNoResults => 'No Results';

  @override
  String get taskExpertSearchHint => 'Search experts by name or skill...';

  @override
  String get taskExpertNoResults => 'No experts found matching your search';

  @override
  String get taskExpertServiceDetail => 'Service Detail';

  @override
  String get taskExpertPrice => 'Price';

  @override
  String get taskExpertDescription => 'Description';

  @override
  String get taskExpertCategory => 'Category';

  @override
  String get taskExpertDeliveryTime => 'Delivery Time';

  @override
  String get taskExpertMyApplications => 'My Service Applications';

  @override
  String get taskExpertNoApplications => 'No Applications';

  @override
  String get taskExpertNoApplicationsMessage =>
      'You haven\'t submitted any service applications yet';

  @override
  String get taskExpertIntro => 'Task Experts';

  @override
  String get taskExpertIntroTitle => 'Become a Task Expert';

  @override
  String get taskExpertIntroSubtitle =>
      'Showcase your skills and earn more from completing tasks';

  @override
  String get taskExpertBenefit1Title => 'Verified Expert Badge';

  @override
  String get taskExpertBenefit1Desc =>
      'Stand out with a verified expert badge on your profile';

  @override
  String get taskExpertBenefit2Title => 'Priority Matching';

  @override
  String get taskExpertBenefit2Desc =>
      'Get matched with tasks that match your expertise first';

  @override
  String get taskExpertBenefit3Title => 'Higher Earnings';

  @override
  String get taskExpertBenefit3Desc =>
      'Experts earn up to 20% more on task completions';

  @override
  String get leaderboardScore => 'Score';

  @override
  String get leaderboardApplySuccess =>
      'Leaderboard application submitted successfully';

  @override
  String get leaderboardDescriptionHint => 'Describe this leaderboard';

  @override
  String get leaderboardTitle => 'Title';

  @override
  String get leaderboardTitleHint => 'Enter leaderboard title';

  @override
  String get leaderboardRules => 'Rules';

  @override
  String get leaderboardRulesHint => 'Describe the rules for this leaderboard';

  @override
  String get leaderboardLocation => 'Location';

  @override
  String get leaderboardLocationHint =>
      'Enter the location for this leaderboard';

  @override
  String get leaderboardApplicationReason => 'Application Reason';

  @override
  String get leaderboardApplicationReasonHint =>
      'Why do you want to create this leaderboard?';

  @override
  String get leaderboardFillRequired => 'Please fill in all required fields';

  @override
  String get leaderboardSubmitApply => 'Submit Application';

  @override
  String get leaderboardApply => 'Apply for Leaderboard';

  @override
  String get leaderboardItemScore => 'Score';

  @override
  String get leaderboardSubmitSuccess => 'Entry submitted successfully';

  @override
  String get leaderboardSubmit => 'Submit';

  @override
  String get paymentStripeConnect => 'Stripe Connect Setup';

  @override
  String get paymentConnectPayments => 'Connect Payments';

  @override
  String get paymentConnectPayouts => 'Connect Payouts';

  @override
  String get paymentNoPayments => 'No Payments';

  @override
  String get paymentNoPaymentsMessage =>
      'You don\'t have any payment records yet';

  @override
  String get paymentNoPayouts => 'No Payouts';

  @override
  String get paymentNoPayoutsMessage =>
      'You don\'t have any payout records yet';

  @override
  String get paymentExpired => 'Payment Expired';

  @override
  String get paymentExpiredMessage =>
      'Payment time has expired, please initiate payment again.';

  @override
  String get paymentCountdownTimeout => 'Payment Timed Out';

  @override
  String get paymentCountdownCompleteInTime =>
      'Please complete payment within the time limit';

  @override
  String paymentCountdownTimeLeft(String time) {
    return 'Time remaining: $time';
  }

  @override
  String get paymentApplePayIOSOnly =>
      'Apple Pay is only available on iOS devices';

  @override
  String get paymentApplePayNotSupported =>
      'Your device does not support Apple Pay, please use another payment method';

  @override
  String get paymentNetworkConnectionFailed =>
      'Network connection failed, please check your network and try again.';

  @override
  String get paymentRequestTimeout =>
      'Request timeout, please try again later.';

  @override
  String paymentRemainingTime(String param1) {
    return 'Payment remaining time: $param1';
  }

  @override
  String get paymentOrderInfo => 'Order Information';

  @override
  String get paymentTaskNumber => 'Task Number';

  @override
  String get paymentOriginalPrice => 'Original Price';

  @override
  String paymentDiscount(String param1) {
    return 'Discount ($param1)';
  }

  @override
  String get paymentFinalAmount => 'Final Payment Amount';

  @override
  String get paymentMethod => 'Payment Method';

  @override
  String get paymentCreditDebitCard => 'Credit/Debit Card';

  @override
  String get paymentFastSecure => 'Fast and secure payment';

  @override
  String get paymentWeChatPay => 'WeChat Pay';

  @override
  String get paymentAlipay => 'Alipay';

  @override
  String get paymentCouponSelected => 'Coupon Selected';

  @override
  String get paymentSelectCoupon => 'Select Coupon';

  @override
  String get paymentConfirmFree => 'Confirm (Free)';

  @override
  String paymentPayNow(String param1) {
    return 'Pay Now $param1';
  }

  @override
  String get paymentCancelPayment => 'Cancel Payment';

  @override
  String get paymentCancelPaymentConfirm =>
      'Are you sure you want to cancel payment?';

  @override
  String get paymentContinuePayment => 'Continue Payment';

  @override
  String get paymentLoadFailed => 'Load Failed';

  @override
  String get paymentCoupon => 'Coupon';

  @override
  String paymentApplePayLabel(int param1) {
    return 'Task #$param1';
  }

  @override
  String get profileTaskCount => 'Tasks';

  @override
  String get profileRating => 'Rating';

  @override
  String get profileNoRecentTasks => 'No recent tasks';

  @override
  String get notificationMarkAllRead => 'Mark all read';

  @override
  String get notificationEmpty => 'No Notifications';

  @override
  String get notificationEmptyMessage =>
      'You\'re all caught up! No new notifications.';

  @override
  String get notificationAll => 'All Notifications';

  @override
  String get notificationTask => 'Task Notifications';

  @override
  String get notificationForum => 'Forum Notifications';

  @override
  String get notificationInteraction => 'Interaction Messages';

  @override
  String get errorNetworkTimeout => 'Network connection timed out';

  @override
  String get errorRequestFailedGeneric => 'Request failed';

  @override
  String get errorRequestCancelled => 'Request cancelled';

  @override
  String get errorNetworkConnection => 'Network connection failed';

  @override
  String get errorUnknownGeneric => 'An unknown error occurred';

  @override
  String get errorInsufficientFunds =>
      'Insufficient balance. Please change payment method or top up.';

  @override
  String get errorCardDeclined =>
      'Card declined. Please change card or contact your bank.';

  @override
  String get errorExpiredCard => 'Card expired. Please use a different card.';

  @override
  String get searchTitle => 'Search';

  @override
  String get searchHint => 'Search tasks, posts, items';

  @override
  String get searchTryDifferent => 'Try searching with different keywords';

  @override
  String searchResultCount(int count) {
    return 'Found $count results';
  }

  @override
  String get searchRecentSearches => 'Recent searches';

  @override
  String get searchClearHistory => 'Clear search history';

  @override
  String get networkOnline => 'Network restored';

  @override
  String get notificationPermissionTitle => 'Notification Permission Required';

  @override
  String get notificationPermissionDescription =>
      'Stay updated with:\n\n• Task status updates\n• New message alerts\n• Task matching recommendations\n• Promotional notifications';

  @override
  String get notificationPermissionEnable => 'Enable Notifications';

  @override
  String get notificationPermissionSkip => 'Skip for now';

  @override
  String get feedbackPublishSuccess => 'Published successfully';

  @override
  String get feedbackPublishFailed => 'Publish failed';

  @override
  String get feedbackTaskPublishSuccess => 'Task published successfully';

  @override
  String get feedbackPostPublishSuccess => 'Post published successfully';

  @override
  String get feedbackFillTitleAndContent => 'Please fill in title and content';

  @override
  String get feedbackSelectCategory => 'Please select a category';

  @override
  String feedbackPickImageFailed(String error) {
    return 'Failed to pick image: $error';
  }

  @override
  String get feedbackSaveSuccess => 'Saved successfully';

  @override
  String get feedbackSaveFailed => 'Save failed';

  @override
  String get feedbackOperationSuccess => 'Operation successful';

  @override
  String get feedbackOperationFailed => 'Operation failed';

  @override
  String get feedbackLoadFailed => 'Load failed';

  @override
  String get feedbackNetworkError => 'Network error, please try again';

  @override
  String get feedbackDeleteSuccess => 'Deleted successfully';

  @override
  String get feedbackCopySuccess => 'Copied to clipboard';

  @override
  String errorPageNotFound(String uri) {
    return 'Page not found: $uri';
  }

  @override
  String get errorServerTitle => 'Server Error';

  @override
  String get errorServerMessage =>
      'Server is temporarily unavailable, please try again later';

  @override
  String get errorLoadFailedTitle => 'Load Failed';

  @override
  String get errorLoadFailedMessage => 'An error occurred while loading data';

  @override
  String get errorUnauthorizedTitle => 'Unauthorized';

  @override
  String get errorUnauthorizedMessage =>
      'You do not have permission to access this content';

  @override
  String get errorContentNotFoundTitle => 'Content Not Found';

  @override
  String get errorContentNotFoundMessage =>
      'The content you are looking for does not exist or has been removed';

  @override
  String get errorNetworkTitle => 'Network Connection Failed';

  @override
  String get errorNetworkMessage =>
      'Please check your network connection and try again';

  @override
  String get emptyNoData => 'No Data';

  @override
  String get emptyNoMessages => 'No Messages';

  @override
  String get emptyNoMessagesDescription => 'No messages received yet';

  @override
  String get emptyNoTasksDescription =>
      'No tasks available. Tap below to create a new task';

  @override
  String get emptyNoSearchResultsTitle => 'No Results Found';

  @override
  String get emptyNoSearchResultsDescription => 'No related content found';

  @override
  String emptyNoSearchResultsWithKeyword(String keyword) {
    return 'No results found for \"$keyword\"';
  }

  @override
  String get emptyNoFavoritesDescription => 'Your favorites will appear here';

  @override
  String get emptyNoNotificationsDescription =>
      'Your notifications will appear here';

  @override
  String get sidebarDiscover => 'Discover';

  @override
  String get sidebarAccount => 'Account';

  @override
  String get sidebarWallet => 'Wallet';

  @override
  String get commonOpenInBrowser => 'Open in browser';

  @override
  String get commonFree => 'Free';

  @override
  String get commonRetryText => 'Retry';

  @override
  String get locationTaskLocation => 'Task Location';

  @override
  String get locationGetFailed => 'Failed to get location';

  @override
  String get locationEnableLocationService =>
      'Please enable location services on your device first';

  @override
  String get locationOpenMapFailed => 'Failed to open map';

  @override
  String get notificationPermissionMessage =>
      'You have denied notification permission. Please enable it in system settings.';

  @override
  String get notificationPermissionLater => 'Maybe Later';

  @override
  String permissionRequired(String permissionName) {
    return '$permissionName permission required';
  }

  @override
  String permissionEnableInSettings(String permissionName) {
    return 'Please enable $permissionName permission in system settings and try again';
  }

  @override
  String permissionRequiredForFeature(String permissionName) {
    return 'This feature requires $permissionName permission to work';
  }

  @override
  String get badgeStudent => 'Student';

  @override
  String get badgeExpert => 'Expert';

  @override
  String get activityCampusActivities => 'Campus Activities';

  @override
  String get activityDetailTitle => 'Activity Details';

  @override
  String get activityInfoTitle => 'Activity Info';

  @override
  String get activityParticipantCount => 'Participants';

  @override
  String get activityDiscount => 'Discount';

  @override
  String get activityRewardType => 'Reward Type';

  @override
  String get activitySignupSuccess => 'Registration Successful';

  @override
  String get authResetPassword => 'Reset Password';

  @override
  String get authCodeSent => 'Verification code sent';

  @override
  String get authEnterEmailPlaceholder => 'Enter email address';

  @override
  String get authPasswordLabel => 'Password';

  @override
  String get authPasswordPlaceholder => 'Enter password';

  @override
  String get authCodePlaceholder => 'Enter verification code';

  @override
  String get authPhonePlaceholder => '7XXX XXXXXX';

  @override
  String get authConfirmPassword => 'Confirm Password';

  @override
  String get authConfirmPasswordPlaceholder => 'Enter password again';

  @override
  String get authPasswordRequirement =>
      'At least 8 characters with letters and numbers';

  @override
  String get authPleaseAgreeToTerms =>
      'Please read and agree to the Terms and Privacy Policy';

  @override
  String get authPleaseEnterValidEmail => 'Please enter a valid email address';

  @override
  String get authIAgreePrefix => 'I have read and agree to the ';

  @override
  String get authAnd => ' and ';

  @override
  String get forumPostDetail => 'Post Detail';

  @override
  String get forumWriteComment => 'Write a comment...';

  @override
  String chatUserTitle(String userId) {
    return 'User $userId';
  }

  @override
  String chatTaskTitle(int taskId) {
    return 'Task $taskId';
  }

  @override
  String get chatInputHint => 'Type a message...';

  @override
  String get chatImageLabel => 'Photo';

  @override
  String get chatSendImageConfirmTitle => 'Send image';

  @override
  String get chatCameraLabel => 'Camera';

  @override
  String get chatTaskCompleted => 'Completed';

  @override
  String get chatHasIssue => 'Has Issue';

  @override
  String get chatRequestRefund => 'Request Refund';

  @override
  String get chatUploadProof => 'Upload Proof';

  @override
  String get chatViewDetail => 'View Details';

  @override
  String get chatCopy => 'Copy';

  @override
  String get chatTranslate => 'Translate';

  @override
  String get chatCopied => 'Copied';

  @override
  String get chatPinToTop => 'Pin';

  @override
  String get chatUnpin => 'Unpin';

  @override
  String get chatDeleteChat => 'Delete';

  @override
  String get chatDeletedHint =>
      'Chat deleted. It will reappear when new messages arrive.';

  @override
  String get chatPinnedHint => 'Chat pinned to top';

  @override
  String get chatUnpinnedHint => 'Chat unpinned';

  @override
  String get chatTaskDetailLabel => 'Task Details';

  @override
  String get chatAddressLabel => 'Address';

  @override
  String get tasksSortLatest => 'Latest';

  @override
  String get tasksSortHighestPay => 'Highest Pay';

  @override
  String get tasksSortDeadline => 'Ending Soon';

  @override
  String get tasksProcessing => 'Processing...';

  @override
  String get tasksApplyForTask => 'Apply';

  @override
  String get tasksCancelApplication => 'Cancel Application';

  @override
  String get tasksCompleteTask => 'Complete Task';

  @override
  String get tasksConfirmComplete => 'Confirm Complete';

  @override
  String get fleaMarketChat => 'Chat';

  @override
  String get fleaMarketPurchaseInDev => 'Purchase feature coming soon';

  @override
  String get fleaMarketSeller => 'Seller';

  @override
  String get fleaMarketCreateTitle => 'List Item';

  @override
  String get fleaMarketTitlePlaceholder => 'Enter item title';

  @override
  String get fleaMarketDescPlaceholder => 'Describe your item...';

  @override
  String get fleaMarketSelectCategory => 'Select category';

  @override
  String get fleaMarketLocationPlaceholder => 'e.g. North Campus Gate';

  @override
  String get fleaMarketSelectImageFailed => 'Failed to select image';

  @override
  String get fleaMarketInvalidPrice => 'Please enter a valid price';

  @override
  String get profileEditProfileTitle => 'Edit Profile';

  @override
  String get profileSaveButton => 'Save';

  @override
  String get profileNamePlaceholder => 'Enter name';

  @override
  String get profileBioPlaceholder => 'Tell us about yourself...';

  @override
  String get profileLocationPlaceholder => 'e.g. London';

  @override
  String get profileMyPostsEmpty => 'No Posts';

  @override
  String get profileAcceptedTasks => 'Accepted';

  @override
  String get walletPointsBalance => 'Points Balance';

  @override
  String get walletUnwithdrawnIncome => 'Unwithdrawn Income';

  @override
  String get walletTotalEarned => 'Total Earned';

  @override
  String get walletTotalSpent => 'Total Spent';

  @override
  String get walletPaymentAccount => 'Payment Account';

  @override
  String get walletPayoutRecords => 'Payout Records';

  @override
  String get walletTransactionRecords => 'Transactions';

  @override
  String get walletNoTransactions => 'No Transactions';

  @override
  String get walletViewMore => 'View More Transactions';

  @override
  String get walletMyCoupons => 'My Coupons';

  @override
  String get walletNoCoupons => 'No Coupons';

  @override
  String get settingsGoLogin => 'Login';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsPaymentReceiving => 'Payment & Receiving';

  @override
  String get settingsExpenseManagement => 'Expense Management';

  @override
  String get settingsPaymentHistory => 'Payment History';

  @override
  String get settingsCookiePolicy => 'Cookie Policy';

  @override
  String get settingsEmail => 'Email';

  @override
  String get settingsOther => 'Other';

  @override
  String get settingsClearCache => 'Clear Cache';

  @override
  String get settingsDangerZone => 'Danger Zone';

  @override
  String get couponPointsTab => 'Points';

  @override
  String get couponCouponsTab => 'Coupons';

  @override
  String get couponCheckInTab => 'Check-in';

  @override
  String get couponRedeemReward => 'Redeem Reward';

  @override
  String get couponRedeemCode => 'Redeem Code';

  @override
  String get couponNoPointsRecords => 'No Points Records';

  @override
  String get couponEnterInviteCodeTitle => 'Enter Invite Code';

  @override
  String get couponEnterInviteCodeHint => 'Enter invite code or redeem code';

  @override
  String get couponNoCoupons => 'No Coupons';

  @override
  String get couponClaim => 'Claim';

  @override
  String get customerServiceRateTitle => 'Rate Support';

  @override
  String get customerServiceRateHint => 'Leave your feedback (optional)';

  @override
  String get customerServiceEndTitle => 'End Conversation';

  @override
  String get customerServiceEndMessage =>
      'Are you sure you want to end this conversation?';

  @override
  String get customerServiceEndButton => 'End';

  @override
  String get customerServiceRefresh => 'Refresh';

  @override
  String get notificationSystemTab => 'System';

  @override
  String get notificationInteractionTab => 'Interactions';

  @override
  String get notificationTaskChatTitle => 'Task Chat';

  @override
  String get notificationNoTaskChats => 'No Task Chats';

  @override
  String get onboardingWelcome => 'Welcome to Link²Ur';

  @override
  String get onboardingPublishTask => 'Post Tasks';

  @override
  String get onboardingAcceptTask => 'Accept Tasks';

  @override
  String get onboardingSafePayment => 'Safe Payment';

  @override
  String get onboardingSafePaymentSubtitle => 'Funds are protected';

  @override
  String get onboardingCommunity => 'Community';

  @override
  String get searchTasks => 'Search Tasks';

  @override
  String get searchFleaMarket => 'Search Items';

  @override
  String get searchForum => 'Search Posts';

  @override
  String get searchTasksTitle => 'Tasks';

  @override
  String get searchForumTitle => 'Forum';

  @override
  String get searchFleaMarketTitle => 'Flea Market';

  @override
  String get searchExpertsTitle => 'Experts';

  @override
  String get searchActivitiesTitle => 'Activities';

  @override
  String get searchLeaderboardsTitle => 'Leaderboards';

  @override
  String get searchLeaderboardItemsTitle => 'Leaderboard Items';

  @override
  String get searchForumCategoriesTitle => 'Forum Categories';

  @override
  String get leaderboardRankLabel => 'Rank';

  @override
  String get taskExpertNotFound => 'Expert not found';

  @override
  String get taskExpertCompletedOrders => 'Completed';

  @override
  String get taskExpertServices => 'Services';

  @override
  String get taskExpertBook => 'Book';

  @override
  String get createTaskDescPlaceholder =>
      'Describe task requirements in detail...';

  @override
  String get createTaskLocationPlaceholder => 'Enter task location';

  @override
  String get createTaskPublish => 'Publish Task';

  @override
  String get infoFAQTitle => 'FAQ';

  @override
  String get infoAboutTitle => 'About';

  @override
  String get infoFAQAccountTitle => 'Account';

  @override
  String get infoFAQTaskTitle => 'Tasks';

  @override
  String get infoFAQPaymentTitle => 'Payment & Security';

  @override
  String get infoTermsTitle => 'Terms of Service';

  @override
  String get infoPrivacyTitle => 'Privacy Policy';

  @override
  String get infoCookieTitle => 'Cookie Policy';

  @override
  String get infoVipCenter => 'VIP Center';

  @override
  String get infoVipPriority => 'Priority Orders';

  @override
  String get infoVipBadge => 'VIP Badge';

  @override
  String get infoVipFeeReduction => 'Fee Reduction';

  @override
  String get infoVipCustomerService => 'VIP Support';

  @override
  String get infoVipPointsBoost => 'Points Boost';

  @override
  String get infoVipSubscribe => 'Subscribe to VIP';

  @override
  String get infoVipPriorityRecommend => 'Priority Listing';

  @override
  String get infoVipBadgeLabel => 'VIP Badge';

  @override
  String get infoVipFeeDiscount => 'Fee Discount';

  @override
  String get infoVipExclusiveCoupon => 'Exclusive Coupons';

  @override
  String get infoVipDataAnalytics => 'Data Analytics';

  @override
  String get infoVipMonthly => 'Monthly';

  @override
  String get infoVipYearly => 'Yearly';

  @override
  String get vipPurchaseConfirm => 'Confirm';

  @override
  String get vipPurchaseRestoreMessage =>
      'Purchase history checked. Active subscriptions will be restored automatically.';

  @override
  String get vipPurchaseNoPlans => 'No VIP plans available';

  @override
  String get vipPurchaseReload => 'Reload';

  @override
  String get homeSecondHandMarket => 'Second-hand Market';

  @override
  String get homeSecondHandSubtitle => 'Pre-owned items at great prices';

  @override
  String get homeStudentVerification => 'Student Verification';

  @override
  String get homeStudentVerificationSubtitle =>
      'Verify to unlock more benefits';

  @override
  String get homeBecomeExpert => 'Become an Expert';

  @override
  String get homeBecomeExpertSubtitle =>
      'Showcase skills, get more opportunities';

  @override
  String get homeNewUserReward => 'New User Reward';

  @override
  String get homeNewUserRewardSubtitle => 'Complete first order to earn';

  @override
  String get homeInviteFriends => 'Invite Friends';

  @override
  String get homeInviteFriendsSubtitle => 'Invite friends to earn points';

  @override
  String get homeDailyCheckIn => 'Daily Check-in';

  @override
  String get homeDailyCheckInSubtitle => 'Check in daily for rewards';

  @override
  String get homeCampusLife => 'Campus Life Sharing';

  @override
  String get homeUsedBooks => 'Used Books for Sale';

  @override
  String get homeWeeklyExperts => 'Weekly Expert Leaderboard';

  @override
  String get homeLoadNearbyTasks => 'Load Nearby Tasks';

  @override
  String get homeBrowseExperts => 'Browse Experts';

  @override
  String get homeDiscoverMore => 'Discover More';

  @override
  String get discoveryFeedTypePost => 'Post';

  @override
  String get discoveryFeedTypeProduct => 'Product';

  @override
  String get discoveryFeedTypeCompetitorReview => 'Competitor Review';

  @override
  String get discoveryFeedTypeServiceReview => 'Service Review';

  @override
  String get discoveryFeedTypeRanking => 'Leaderboard';

  @override
  String get discoveryFeedTypeService => 'Expert Service';

  @override
  String get mainPublishFleaMarket => 'List Item';

  @override
  String get linkCopied => 'Link copied';

  @override
  String get paymentAlipaySymbol => 'A';

  @override
  String authResendCountdown(int countdown) {
    return 'Resend in ${countdown}s';
  }

  @override
  String get authPasswordsDoNotMatch => 'Passwords do not match';

  @override
  String get authPleaseEnterEmail => 'Please enter your email';

  @override
  String get authEmailFormatInvalid => 'Invalid email format';

  @override
  String get authResetPasswordDesc =>
      'Enter your registered email and we will send a verification code to help you reset your password.';

  @override
  String get authCreateAccount => 'Create Account';

  @override
  String get authAlreadyHaveAccount => 'Already have an account?';

  @override
  String get authNewPassword => 'New Password';

  @override
  String get authEnterNewPassword => 'Please enter a new password';

  @override
  String get authPasswordMinLength => 'Password must be at least 8 characters';

  @override
  String get authConfirmNewPassword => 'Confirm New Password';

  @override
  String get authForgotPasswordQuestion => 'Forgot password?';

  @override
  String get authRegisterNewAccount => 'Create account';

  @override
  String get authRegisterSubtitle => 'Join Link²Ur, start exchanging skills';

  @override
  String get homeLoadFailed => 'Failed to load';

  @override
  String get homePublishTask => 'Post Task';

  @override
  String get homeDeadlineExpired => 'Expired';

  @override
  String homeDeadlineDays(int days) {
    return '${days}d left';
  }

  @override
  String homeDeadlineHours(int hours) {
    return '${hours}h left';
  }

  @override
  String homeDeadlineMinutes(int minutes) {
    return '${minutes}m left';
  }

  @override
  String get homeDefaultUser => 'User';

  @override
  String get homeClassmate => 'Linker';

  @override
  String get homePostedNewPost => 'posted a new topic';

  @override
  String get homePostedNewProduct => 'listed a new item';

  @override
  String get homeSystemUser => 'System';

  @override
  String get homeCreatedLeaderboard => 'created a new leaderboard';

  @override
  String get homeCampusLifeDesc => 'Sharing my campus life';

  @override
  String get homeSearchCategory => 'Search categories';

  @override
  String get homeSearchTasks => 'Search tasks';

  @override
  String get homeSearchFleaMarket => 'Search marketplace';

  @override
  String get homeSearchPosts => 'Search posts';

  @override
  String homeSearchQueryResult(String query) {
    return 'Search \"$query\"';
  }

  @override
  String get homePressEnterToSearch => 'Press Enter to search';

  @override
  String get taskCategoryPickup => 'Pickup';

  @override
  String get taskCategoryTutoring => 'Tutoring';

  @override
  String get taskCategoryMoving => 'Moving';

  @override
  String get taskCategoryPurchasing => 'Purchasing';

  @override
  String get taskCategoryDogWalking => 'Dog Walking';

  @override
  String get taskCategoryTranslation => 'Translation';

  @override
  String get taskCategoryPhotography => 'Photography';

  @override
  String get taskCategoryTutor => 'Tutoring';

  @override
  String get taskDetailProcessing => 'Processing...';

  @override
  String get taskDetailApplyForTask => 'Apply';

  @override
  String get taskDetailCancelApplication => 'Cancel Application';

  @override
  String get taskDetailCompleteTask => 'Complete Task';

  @override
  String get taskDetailParticipantCount => 'Participants';

  @override
  String get taskSortBy => 'Sort by';

  @override
  String get taskSortLatest => 'Latest';

  @override
  String get taskSortHighestPay => 'Highest Pay';

  @override
  String get taskSortNearDeadline => 'Near Deadline';

  @override
  String get taskDeadlineExpired => 'Expired';

  @override
  String taskDeadlineMinutes(int minutes) {
    return '${minutes}m left';
  }

  @override
  String taskDeadlineHours(int hours) {
    return '${hours}h left';
  }

  @override
  String taskDeadlineDays(int days) {
    return '${days}d left';
  }

  @override
  String taskDeadlineDate(int month, int day) {
    return '$month/$day deadline';
  }

  @override
  String get taskCategoryHousekeepingLife => 'Housekeeping';

  @override
  String get createTaskType => 'Task Type';

  @override
  String get createTaskTitleField => 'Task Title';

  @override
  String get createTaskTitleHint => 'Enter task title';

  @override
  String get createTaskDescHint => 'Describe task requirements in detail...';

  @override
  String get createTaskLocation => 'Location';

  @override
  String get createTaskLocationHint => 'Enter task location';

  @override
  String get createTaskDeadline => 'Deadline';

  @override
  String get createTaskSelectDeadline => 'Select deadline';

  @override
  String get createTaskCategoryDelivery => 'Delivery';

  @override
  String get createTaskCategoryShopping => 'Shopping';

  @override
  String get createTaskCategoryTutoring => 'Tutoring';

  @override
  String get createTaskCategoryTranslation => 'Translation';

  @override
  String get createTaskCategoryDesign => 'Design';

  @override
  String get createTaskCategoryProgramming => 'Programming';

  @override
  String get createTaskCategoryWriting => 'Writing';

  @override
  String get createTaskCategoryPhotography => 'Photography';

  @override
  String get createTaskCategoryMoving => 'Moving';

  @override
  String get createTaskCategoryCleaning => 'Cleaning';

  @override
  String get createTaskCategoryRepair => 'Repair';

  @override
  String get createTaskCategoryOther => 'Other';

  @override
  String get profileDirectRequestValidation =>
      'Please fill in the title and a valid price (≥£1)';

  @override
  String get profileDirectRequestHintLocation => 'Location';

  @override
  String get profileDirectRequestHintDeadline => 'Deadline (optional)';

  @override
  String get taskTypeHousekeeping => 'Housekeeping';

  @override
  String get taskTypeCampusLife => 'Campus Life';

  @override
  String get taskTypeSecondHandRental => 'Second-hand & Rental';

  @override
  String get taskTypeErrandRunning => 'Errand Running';

  @override
  String get taskTypeSkillService => 'Skill Service';

  @override
  String get taskTypeSocialHelp => 'Social Help';

  @override
  String get taskTypeTransportation => 'Transportation';

  @override
  String get taskTypePetCare => 'Pet Care';

  @override
  String get taskTypeLifeConvenience => 'Life Convenience';

  @override
  String get taskTypeOther => 'Other';

  @override
  String get taskTypeCampusLifeNeedVerify =>
      'Publishing \"Campus Life\" tasks requires student email verification';

  @override
  String get taskDetailNoImages => 'No images';

  @override
  String forumUserFallback(String userId) {
    return 'User $userId';
  }

  @override
  String get forumNoLeaderboard => 'No leaderboard';

  @override
  String get forumNoLeaderboardMessage => 'No leaderboard available';

  @override
  String get forumNoPostsHint =>
      'No posts yet. Tap below to create the first one!';

  @override
  String get forumEnterTitle => 'Enter title';

  @override
  String get forumShareThoughts => 'Share your thoughts...';

  @override
  String get forumSelectCategory => 'Select category';

  @override
  String get settingsPleaseLoginFirst => 'Please login first';

  @override
  String get settingsUnknown => 'Unknown';

  @override
  String get settingsLoading => 'Loading...';

  @override
  String get settingsNotBound => 'Not linked';

  @override
  String get settingsChinese => 'Chinese';

  @override
  String get walletPayoutAccount => 'Payout Account';

  @override
  String get walletActivated => 'Activated, ready to receive';

  @override
  String get walletConnectedPending => 'Connected, pending activation';

  @override
  String get walletNotConnected => 'Not connected';

  @override
  String get walletActivatedShort => 'Activated';

  @override
  String get walletPendingActivation => 'Pending';

  @override
  String get walletNotConnectedShort => 'Not connected';

  @override
  String get walletViewAccountDetail => 'View account details';

  @override
  String get walletSetupPayoutAccount => 'Setup payout account';

  @override
  String get walletPayoutRecordsFull => 'Payout Records';

  @override
  String get walletWithdrawalRecords => 'Withdrawal Records';

  @override
  String get walletTransactionHistory => 'Transaction History';

  @override
  String get walletTopUp => 'Top Up';

  @override
  String get walletTransfer => 'Transfer';

  @override
  String get walletViewAll => 'View All';

  @override
  String get walletTransactionsDesc =>
      'Your points transaction history will appear here';

  @override
  String get walletNoCouponsDesc => 'You don\'t have any coupons';

  @override
  String get walletToday => 'Today';

  @override
  String get walletYesterday => 'Yesterday';

  @override
  String get walletCheckingIn => 'Checking in...';

  @override
  String get walletDailyCheckIn => 'Daily Check-in';

  @override
  String get myTasksTitle => 'My Tasks';

  @override
  String get myTasksAccepted => 'Accepted';

  @override
  String get myTasksPosted => 'Posted';

  @override
  String get myTasksGoAccept => 'Browse Tasks';

  @override
  String get profileBio => 'Bio';

  @override
  String get profileBioHint => 'Tell us about yourself...';

  @override
  String get profileCity => 'City';

  @override
  String get profileCityHint => 'e.g. London';

  @override
  String get profileNameRequired => 'Please enter your name';

  @override
  String get profileNameMinLength => 'Name must be at least 3 characters';

  @override
  String get profileAnonymousUser => 'Anonymous';

  @override
  String get myPostsEmpty => 'No posts';

  @override
  String get myPostsEmptyDesc => 'You haven\'t posted anything yet';

  @override
  String get fleaMarketSold => 'Sold';

  @override
  String get fleaMarketDelisted => 'Delisted';

  @override
  String get fleaMarketItemReserved => 'Item Reserved';

  @override
  String get fleaMarketCategoryAll => 'All';

  @override
  String get fleaMarketCategoryDailyUse => 'Daily Use';

  @override
  String get fleaMarketImageSelectFailed => 'Failed to select image';

  @override
  String get fleaMarketTitleMinLength => 'Title must be at least 2 characters';

  @override
  String get fleaMarketTitleRequired => 'Please enter a title';

  @override
  String get fleaMarketDescOptional => 'Description (optional)';

  @override
  String get fleaMarketDescHint => 'Describe your item...';

  @override
  String get fleaMarketLocationOptional => 'Location (optional)';

  @override
  String get fleaMarketLocationHint => 'e.g. Campus North Gate';

  @override
  String get fleaMarketPriceRequired => 'Please enter a price';

  @override
  String get fleaMarketCategoryLabel => 'Category';

  @override
  String get fleaMarketNoItemsHint =>
      'No items yet. Tap below to list the first one!';

  @override
  String get chatNoMessages => 'No messages yet. Start a conversation!';

  @override
  String get chatInProgress => 'In Progress';

  @override
  String get chatTaskClosed => 'Task Closed';

  @override
  String get chatTaskClosedHint =>
      'This task has been closed, messages are disabled';

  @override
  String get chatTaskCompletedConfirm => 'Task completed, please confirm.';

  @override
  String get chatHasIssueMessage => 'I encountered some issues:';

  @override
  String get activityCheckLater => 'Check back later';

  @override
  String get activityNoAvailableActivities => 'No activities available yet';

  @override
  String get activityRegisterSuccess => 'Registration successful';

  @override
  String get activityRegisterFailed => 'Registration failed';

  @override
  String get activityRegisterNow => 'Register Now';

  @override
  String get activityRegistered => 'Registered';

  @override
  String get activityFullSlots => 'Full';

  @override
  String get activityCancelled => 'Cancelled';

  @override
  String get activityInProgress => 'In Progress';

  @override
  String get activityFree => 'Free';

  @override
  String get activityCash => 'Cash';

  @override
  String get activityPointsReward => 'Points';

  @override
  String get activityCashAndPoints => 'Cash + Points';

  @override
  String get activityInfo => 'Activity Info';

  @override
  String get activityPublisher => 'Publisher';

  @override
  String get activityViewExpertProfileShort => 'View Expert Profile';

  @override
  String get activityParticipantsCount => 'Participants';

  @override
  String get activityStatusLabel => 'Status';

  @override
  String get activityRegistrationDeadline => 'Registration deadline: ';

  @override
  String get activityCurrentApplicants => 'Current applicants: ';

  @override
  String get activityJoinLottery => 'Join Lottery';

  @override
  String get activityAlreadyRegistered => 'Registered';

  @override
  String get activityNoWinners => 'No winners yet';

  @override
  String get activityWinnerList => 'Winner List';

  @override
  String get activityPrizePoints => 'Points Reward';

  @override
  String get activityPrizePhysical => 'Physical Prize';

  @override
  String get activityPrizeVoucher => 'Voucher Code';

  @override
  String get activityPrizeInPerson => 'In-Person Event';

  @override
  String get activityPrize => 'Prize';

  @override
  String activityPrizeCount(Object count) {
    return 'Prize Slots: $count';
  }

  @override
  String get activityYouWon => 'Congratulations! You Won!';

  @override
  String activityYouWonVoucher(Object code) {
    return 'Your voucher code: $code';
  }

  @override
  String get activityNotWon => 'Stay Tuned for Next Event';

  @override
  String get activityDrawCompleted => 'Draw Completed';

  @override
  String get activityLotteryPending => 'Awaiting Draw';

  @override
  String activityPersonCount(int current, int max) {
    return '$current/$max';
  }

  @override
  String get leaderboardNoLeaderboards => 'No leaderboards';

  @override
  String get leaderboardNoLeaderboardsMessage => 'No leaderboards available';

  @override
  String get leaderboardNoCompetitorsHint =>
      'No competitors yet. Tap below to submit the first one!';

  @override
  String leaderboardNetVotesCount(int count) {
    return 'Net $count';
  }

  @override
  String get leaderboardRankFirst => '#1';

  @override
  String get leaderboardRankSecond => '#2';

  @override
  String get leaderboardRankThird => '#3';

  @override
  String get leaderboardDetails => 'Details';

  @override
  String leaderboardCompletedCount(int count) {
    return '$count completed';
  }

  @override
  String get notificationSystemNotifications => 'System';

  @override
  String get notificationInteractionMessages => 'Interactions';

  @override
  String get notificationNoTaskChatDesc =>
      'Accept or post a task to start chatting';

  @override
  String get taskExpertDetailTitle => 'Expert Details';

  @override
  String get taskExpertExpertNotExist => 'Expert not found';

  @override
  String get taskExpertExpertNotExistDesc =>
      'This expert does not exist or has been removed';

  @override
  String get taskExpertBio => 'Bio';

  @override
  String get taskExpertSpecialties => 'Specialties';

  @override
  String get taskExpertProvidedServices => 'Services Provided';

  @override
  String get taskExpertNoServicesDesc =>
      'This expert hasn\'t listed any services yet';

  @override
  String get taskExpertAccepted => 'Accepted';

  @override
  String get taskExpertRejected => 'Rejected';

  @override
  String get taskExpertAppliedStatus => 'Applied';

  @override
  String get taskExpertApplicationPending =>
      'Your expert application is under review';

  @override
  String get taskExpertApplicationApproved =>
      'Your expert application has been approved!';

  @override
  String get taskExpertApplicationRejected =>
      'Your expert application was not approved';

  @override
  String taskExpertServiceCount(int count) {
    return '$count services';
  }

  @override
  String taskExpertShareTitle(String name) {
    return 'Share Expert - $name';
  }

  @override
  String taskExpertShareText(String name) {
    return 'Check out this expert: $name';
  }

  @override
  String get infoFAQAccountQ1 => 'How do I register an account?';

  @override
  String get infoFAQAccountA1 =>
      'You can register using your email address or phone number. Click \'Register\' on the login page and follow the instructions.';

  @override
  String get infoFAQAccountQ2 => 'How do I reset my password?';

  @override
  String get infoFAQAccountA2 =>
      'Click \'Forgot Password\' on the login page, enter your registered email and follow the verification steps to reset it.';

  @override
  String get infoFAQAccountQ3 => 'How do I edit my profile?';

  @override
  String get infoFAQAccountA3 =>
      'Go to Profile > Edit Profile to update your avatar, nickname, bio and other information.';

  @override
  String get infoFAQAccountQ4 => 'How do I delete my account?';

  @override
  String get infoFAQAccountA4 =>
      'Go to Settings > Account Security > Delete Account. Please note this action is irreversible.';

  @override
  String get infoFAQTaskQ1 => 'How do I publish a task?';

  @override
  String get infoFAQTaskA1 =>
      'Tap the \'+\' button at the bottom of the screen, select \'Publish Task\', fill in the details and submit.';

  @override
  String get infoFAQTaskQ2 => 'How do I accept a task?';

  @override
  String get infoFAQTaskA2 =>
      'Browse available tasks, tap on one to view details, then click \'Accept Task\' to start.';

  @override
  String get infoFAQTaskQ3 => 'How do I cancel a task?';

  @override
  String get infoFAQTaskA3 =>
      'Go to the task detail page and click \'Cancel Task\'. Please note that cancellation policies may apply.';

  @override
  String get infoFAQTaskQ4 => 'What if there is a dispute?';

  @override
  String get infoFAQTaskA4 =>
      'You can raise a dispute via the task chat page. Our customer service team will assist in resolving it.';

  @override
  String get infoFAQPaymentQ1 => 'What payment methods are supported?';

  @override
  String get infoFAQPaymentA1 =>
      'We support Stripe (credit/debit cards), Apple Pay, and WeChat Pay.';

  @override
  String get infoFAQPaymentQ2 => 'How does the escrow system work?';

  @override
  String get infoFAQPaymentA2 =>
      'When you pay for a task, the funds are held securely. The helper receives payment only after you confirm task completion.';

  @override
  String get infoFAQPaymentQ3 => 'How do I request a refund?';

  @override
  String get infoFAQPaymentA3 =>
      'Go to the task detail page and click \'Request Refund\'. Provide a reason and our team will review it within 1-3 business days.';

  @override
  String get infoFAQPaymentQ4 => 'How do I withdraw my earnings?';

  @override
  String get infoFAQPaymentA4 =>
      'Go to Wallet > Withdraw, connect your Stripe account and withdraw to your bank account.';

  @override
  String get vipPlanFeatureMonthly1 => 'Priority task recommendation';

  @override
  String get vipPlanFeatureMonthly2 => 'Exclusive VIP badge';

  @override
  String get vipPlanFeatureMonthly3 => 'Reduced service fees';

  @override
  String get vipPlanFeatureYearly1 => 'All monthly benefits';

  @override
  String get vipPlanFeatureYearly2 => 'Dedicated customer support';

  @override
  String get vipPlanFeatureYearly3 => 'Points boost & exclusive activities';

  @override
  String get vipPlanFeatureYearly4 => 'Data analytics dashboard';

  @override
  String get vipPlanBadgeBestValue => 'Best Value';

  @override
  String get vipRegularUser => 'Regular User';

  @override
  String infoVersionFormat(String version, String buildNumber) {
    return 'Version $version ($buildNumber)';
  }

  @override
  String get infoCopyright => '© 2024 Link²Ur. All rights reserved.';

  @override
  String get chatImagePlaceholder => '[Image]';

  @override
  String get studentVerificationEmailLocked =>
      'Email is locked, please wait for review to complete';

  @override
  String get studentVerificationPending =>
      'Verification under review, please check your email and complete verification';

  @override
  String get purchaseFailed => 'Purchase failed, please try again later.';

  @override
  String get restorePurchaseFailed =>
      'Restore purchase failed, please try again later.';

  @override
  String get onboardingTaskTypeErrand => 'Errand Running';

  @override
  String get onboardingTaskTypeSkill => 'Skill Service';

  @override
  String get onboardingTaskTypeHousekeeping => 'Housekeeping';

  @override
  String get onboardingTaskTypeTransport => 'Transportation';

  @override
  String get onboardingTaskTypeSocial => 'Social Help';

  @override
  String get onboardingTaskTypeCampus => 'Campus Life';

  @override
  String get onboardingTaskTypeSecondhand => 'Secondhand & Rental';

  @override
  String get onboardingTaskTypePetCare => 'Pet Care';

  @override
  String get onboardingTaskTypeConvenience => 'Life Convenience';

  @override
  String get onboardingTaskTypeOther => 'Other';

  @override
  String get fleaMarketCategoryKeyElectronics => 'electronics';

  @override
  String get fleaMarketCategoryKeyBooks => 'books';

  @override
  String get fleaMarketCategoryKeyDaily => 'daily';

  @override
  String get fleaMarketCategoryKeyClothing => 'clothing';

  @override
  String get fleaMarketCategoryKeySports => 'sports';

  @override
  String get fleaMarketCategoryKeyOther => 'other';

  @override
  String get couponRewardPoints50 => '+50 Points';

  @override
  String get couponRewardPoints100Coupon => '+100 Points + Coupon';

  @override
  String get couponRewardPoints500Vip => '+500 Points + VIP Trial';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageChinese => '中文';

  @override
  String get infoTermsContent =>
      'Link²Ur Terms of Service\n\nLast updated: January 1, 2024\n\n1. Service Overview\nLink²Ur is a campus mutual-aid platform designed to help users publish and accept various life service tasks.\n\n2. User Responsibilities\n- Users must provide truthful and accurate personal information\n- Users must comply with platform rules and applicable laws\n- Users are responsible for the content they publish\n\n3. Platform Responsibilities\n- The platform provides information intermediary services\n- The platform implements escrow protection for transaction funds\n- The platform reserves the right to take action against violations\n\n4. Payment & Settlement\n- All payments are processed through third-party payment platforms\n- Tasks are automatically settled upon completion\n- The platform charges reasonable service fees\n\n5. Privacy Protection\nPlease refer to our Privacy Policy for detailed information.\n\n6. Disclaimer\nAs an information intermediary, the platform does not bear direct responsibility for transactions between users.\n\nIf you have any questions, please contact our customer service team.';

  @override
  String get infoPrivacyContent =>
      'Link²Ur Privacy Policy\n\nLast updated: January 1, 2024\n\n1. Information Collection\nWe collect the following types of information:\n- Registration information (name, email, etc.)\n- Location information (for nearby task recommendations)\n- Device information (for push notifications)\n\n2. Information Usage\nWe use your information to:\n- Provide and improve services\n- Personalized recommendations\n- Ensure transaction security\n\n3. Information Storage & Protection\n- Data is stored on secure servers\n- Encryption technology is used to protect data transmission\n- Regular security audits are conducted\n\n4. Information Sharing\nWe do not sell your personal information. We only share in the following cases:\n- With your consent\n- Legal requirements\n- Necessary for service provision\n\n5. Cookie Policy\nWe use cookies to improve user experience.\n\n6. Your Rights\n- Access and modify personal information\n- Delete account\n- Unsubscribe from notifications\n\nFor privacy-related questions, please contact privacy@link2ur.com';

  @override
  String get infoCookieContent =>
      'Link²Ur Cookie Policy\n\nWe use cookies and similar technologies to improve your experience.\n\n1. What are Cookies\nCookies are small text files stored on your device.\n\n2. How We Use Cookies\n- Essential Cookies: Maintain login status\n- Functional Cookies: Remember preferences\n- Analytics Cookies: Improve service quality\n\n3. Managing Cookies\nYou can manage cookie preferences in your device settings.';

  @override
  String get serviceNegotiatePrice => 'Price Negotiation';

  @override
  String get serviceNegotiatePriceHint =>
      'Propose a different price to the expert';

  @override
  String get serviceSelectDeadline => 'Select Deadline';

  @override
  String get serviceApplyOtherSlot => 'Apply for Another Slot';

  @override
  String get publishTitle => 'Publish';

  @override
  String get publishTypeSubtitle => 'Choose what you want to publish';

  @override
  String get publishTaskTab => 'Post Task';

  @override
  String get publishFleaMarketTab => 'Sell Item';

  @override
  String get publishPostTab => 'Forum Post';

  @override
  String get publishTaskCardLabel => 'Post Task';

  @override
  String get publishFleaCardLabel => 'Sell Item';

  @override
  String get publishPostCardLabel => 'Forum Post';

  @override
  String get publishRelatedContent => 'Related Content';

  @override
  String get publishSearchHint =>
      'Search services, activities, items, leaderboards...';

  @override
  String get publishRelatedToMe => 'Related to me';

  @override
  String get publishSearchResults => 'Search results';

  @override
  String get publishNoResultsTryKeywords => 'No results, try other keywords';

  @override
  String get publishSearchAndLink => 'Search and link';

  @override
  String get publishRecentSectionTitle => 'Recent Publishes';

  @override
  String get publishTipsSectionTitle => 'Publish Tips';

  @override
  String get publishRecentEmpty => 'No recent publishes';

  @override
  String get publishTip1 => 'Clear, specific titles get more visibility';

  @override
  String get publishTip2 => 'Clear photos increase views and sales';

  @override
  String get publishTip3 => 'State reward or price upfront to save time';

  @override
  String get publishTip4 => 'Pick the right category for better exposure';

  @override
  String get profileUpdateFailed => 'Update failed';

  @override
  String get profileAvatarUpdated => 'Avatar updated';

  @override
  String get profileUploadFailed => 'Upload failed';

  @override
  String get profilePreferencesUpdated => 'Preferences updated';

  @override
  String get commonSuccess => 'Success';

  @override
  String get commonError => 'Error';

  @override
  String get commonSaved => 'Saved';

  @override
  String get validatorEmailRequired => 'Please enter email address';

  @override
  String get validatorEmailInvalid => 'Please enter a valid email address';

  @override
  String get validatorPhoneRequired => 'Please enter phone number';

  @override
  String get validatorPhoneInvalid => 'Please enter a valid phone number';

  @override
  String get validatorUKPhoneRequired => 'Please enter your phone number';

  @override
  String get validatorUKPhoneInvalid => 'Please enter a valid UK mobile number';

  @override
  String get validatorPasswordRequired => 'Please enter password';

  @override
  String get validatorPasswordMinLength =>
      'Password must be at least 8 characters';

  @override
  String get validatorPasswordFormat =>
      'Password must contain both letters and numbers';

  @override
  String get validatorConfirmPasswordRequired => 'Please confirm password';

  @override
  String get validatorPasswordMismatch => 'Passwords do not match';

  @override
  String get validatorCodeRequired => 'Please enter verification code';

  @override
  String validatorCodeLength(int length) {
    return 'Verification code must be $length digits';
  }

  @override
  String get validatorCodeDigitsOnly =>
      'Verification code must contain only digits';

  @override
  String get validatorUsernameRequired => 'Please enter username';

  @override
  String get validatorUsernameMinLength =>
      'Username must be at least 2 characters';

  @override
  String get validatorUsernameMaxLength =>
      'Username must be at most 20 characters';

  @override
  String get validatorTitleRequired => 'Please enter title';

  @override
  String validatorTitleMaxLength(int maxLength) {
    return 'Title must be at most $maxLength characters';
  }

  @override
  String get validatorDescriptionRequired => 'Please enter description';

  @override
  String validatorDescriptionMaxLength(int maxLength) {
    return 'Description must be at most $maxLength characters';
  }

  @override
  String get validatorAmountRequired => 'Please enter amount';

  @override
  String get validatorAmountInvalid => 'Please enter a valid amount';

  @override
  String get validatorAmountPositive => 'Amount must be greater than 0';

  @override
  String validatorAmountMin(double min) {
    return 'Amount cannot be less than $min';
  }

  @override
  String validatorAmountMax(double max) {
    return 'Amount cannot be greater than $max';
  }

  @override
  String get validatorUrlRequired => 'Please enter URL';

  @override
  String get validatorUrlInvalid => 'Please enter a valid URL';

  @override
  String validatorFieldRequired(String fieldName) {
    return '$fieldName is required';
  }

  @override
  String validatorFieldMinLength(String fieldName, int min) {
    return '$fieldName must be at least $min characters';
  }

  @override
  String validatorFieldMaxLength(String fieldName, int max) {
    return '$fieldName must be at most $max characters';
  }

  @override
  String get timeYesterday => 'Yesterday';

  @override
  String get timeDayBeforeYesterday => 'Day before yesterday';

  @override
  String timeDeadlineMinutes(int minutes) {
    return 'Due in $minutes min';
  }

  @override
  String timeDeadlineHours(int hours) {
    return 'Due in $hours hr';
  }

  @override
  String timeDeadlineDays(int days) {
    return 'Due in $days days';
  }

  @override
  String timeDeadlineDate(String date) {
    return 'Due $date';
  }

  @override
  String get badgeVip => 'VIP';

  @override
  String get badgeSuper => 'Super';

  @override
  String get notificationPermTitle => 'Enable Push Notifications';

  @override
  String get notificationPermDesc =>
      'Stay updated with:\n\n• Task status updates\n• New message alerts\n• Task match recommendations\n• Deals & promotions';

  @override
  String get notificationPermEnable => 'Enable Notifications';

  @override
  String get notificationPermSkip => 'Skip for Now';

  @override
  String get notificationPermSettingsTitle =>
      'Notification Permission Required';

  @override
  String get notificationPermSettingsDesc =>
      'You have denied notification permission. Please enable it manually in system settings.';

  @override
  String get notificationPermSettingsLater => 'Later';

  @override
  String get notificationPermSettingsGo => 'Go to Settings';

  @override
  String get shareTitle => 'Share to';

  @override
  String get shareLinkCopied => 'Link copied';

  @override
  String get shareQQ => 'QQ';

  @override
  String get shareMore => 'More';

  @override
  String get actionItemPublished => 'Item published';

  @override
  String get actionPublishFailed => 'Publish failed';

  @override
  String get actionPurchaseSuccess => 'Purchase successful';

  @override
  String get actionPurchaseFailed => 'Purchase failed';

  @override
  String get actionItemUpdated => 'Item updated';

  @override
  String get actionUpdateFailed => 'Update failed';

  @override
  String get actionRefreshSuccess => 'Refreshed';

  @override
  String get actionRefreshFailed => 'Refresh failed';

  @override
  String get actionApplicationSubmitted => 'Application submitted';

  @override
  String get actionApplicationFailed => 'Application failed';

  @override
  String get actionApplicationCancelled => 'Application cancelled';

  @override
  String get actionCancelFailed => 'Cancel failed';

  @override
  String get actionApplicationAccepted => 'Application accepted';

  @override
  String get actionApplicationRejected => 'Application rejected';

  @override
  String get actionOperationFailed => 'Operation failed';

  @override
  String get actionTaskCompleted => 'Completion submitted';

  @override
  String get actionSubmitFailed => 'Submit failed';

  @override
  String get actionCompletionConfirmed => 'Completion confirmed';

  @override
  String get actionConfirmFailed => 'Confirm failed';

  @override
  String get actionTaskCancelled => 'Task cancelled';

  @override
  String get actionReviewSubmitted => 'Review submitted';

  @override
  String get actionReviewFailed => 'Review failed';

  @override
  String get actionRefundSubmitted => 'Refund request submitted';

  @override
  String get actionRefundFailed => 'Refund request failed';

  @override
  String get actionRefundRevoked => 'Refund request revoked';

  @override
  String get actionRevokeFailed => 'Revoke failed';

  @override
  String get actionDisputeSubmitted => 'Dispute submitted';

  @override
  String get actionDisputeFailed => 'Dispute submission failed';

  @override
  String get actionCheckInSuccess => 'Check-in successful!';

  @override
  String get actionCheckInFailed => 'Check-in failed';

  @override
  String get actionVoteFailed => 'Vote failed';

  @override
  String get actionLeaderboardApplied => 'Application submitted';

  @override
  String get actionLeaderboardSubmitted => 'Submitted successfully';

  @override
  String get actionVerificationSubmitted =>
      'Submitted, please check your email for verification';

  @override
  String get actionVerificationSuccess => 'Verification successful';

  @override
  String get actionVerificationFailed => 'Verification failed';

  @override
  String get actionRenewalSuccess => 'Renewal successful';

  @override
  String get actionRenewalFailed => 'Renewal failed';

  @override
  String get actionRegistrationSuccess => 'Registration successful';

  @override
  String get actionRegistrationFailed => 'Registration failed';

  @override
  String get actionConversationEnded => 'Conversation ended';

  @override
  String get actionEndConversationFailed => 'Failed to end conversation';

  @override
  String get actionFeedbackSuccess => 'Thank you for your feedback';

  @override
  String get actionFeedbackFailed => 'Feedback failed';

  @override
  String get actionCouponClaimed => 'Coupon claimed';

  @override
  String get actionCouponRedeemed => 'Redeemed successfully';

  @override
  String get actionInviteCodeUsed => 'Invite code applied';

  @override
  String get profileRecentPosts => 'Recent Posts';

  @override
  String get profileNoRecentPosts => 'No posts yet';

  @override
  String get profileSoldItems => 'Sold Items';

  @override
  String get profileNoSoldItems => 'No sold items yet';

  @override
  String get profileDirectRequest => 'Request Service';

  @override
  String get profileDirectRequestTitle => 'Send Task Request';

  @override
  String get profileDirectRequestSuccess => 'Task request sent successfully';

  @override
  String get profileDirectRequestHintTitle => 'Task title';

  @override
  String get profileDirectRequestHintDescription =>
      'Task description (optional)';

  @override
  String get profileDirectRequestHintPrice => 'Price';

  @override
  String get profileDirectRequestHintTaskType => 'Task type';

  @override
  String get profileDirectRequestSubmit => 'Send Request';

  @override
  String get profileMySoldItems => 'My Sold Items';

  @override
  String get profileMySoldItemsSubtitle => 'View your sold flea market items';

  @override
  String get commonDefault => 'Default';

  @override
  String get paymentIncorrectCvc => 'Incorrect CVC';

  @override
  String get paymentIncorrectCardNumber => 'Incorrect card number';

  @override
  String get paymentAuthenticationRequired => 'Authentication required';

  @override
  String get paymentProcessingError => 'Payment processing error';

  @override
  String get paymentTooManyRequests => 'Too many requests, please try later';

  @override
  String get paymentInvalidRequest => 'Invalid payment request';

  @override
  String get transactionTypePayment => 'Payment';

  @override
  String get transactionTypePayout => 'Payout';

  @override
  String get transactionTypeRefund => 'Refund';

  @override
  String get transactionTypeFee => 'Service Fee';

  @override
  String get supportChatTitle => 'Linker';

  @override
  String get supportChatConnecting => 'Connecting...';

  @override
  String get supportChatHumanOnline => 'Human agent is online';

  @override
  String get supportChatConnectButton => 'Connect';

  @override
  String get supportChatHumanOffline =>
      'No agents online. Email support@link2ur.com';

  @override
  String get supportChatConnected => 'Human Support';

  @override
  String get supportChatEnded => 'Conversation ended';

  @override
  String get supportChatReturnToAI => 'Back to AI';

  @override
  String get supportChatDivider => 'Connected to human support';

  @override
  String get supportChatHistory => 'History';

  @override
  String get aiChatTitle => 'AI Assistant';

  @override
  String get aiChatNewConversation => 'New conversation';

  @override
  String get aiChatReplying => 'AI is replying...';

  @override
  String get aiChatInputHint => 'Type a message...';

  @override
  String get aiChatViewMyTasks => 'View my tasks';

  @override
  String get aiChatSearchTasks => 'Search available tasks';

  @override
  String get aiChatWelcomeTitle => 'Hi, I\'m Linker';

  @override
  String get aiChatWelcomeSubtitle => 'How can I help you?';

  @override
  String get aiChatWelcomeIntro =>
      'I\'m Link2Ur\'s AI assistant. I can help you check task status, search tasks, answer platform rules, view points and coupons, and more. Type your question below or tap a quick question to get started.';

  @override
  String get aiChatQuickStart => 'Quick start';

  @override
  String get aiChatStartNewConversation => 'Start new conversation';

  @override
  String get aiChatNoConversations => 'No conversations yet';

  @override
  String locationFetchFailed(String error) {
    return 'Failed to get location: $error';
  }

  @override
  String get toolCallQueryMyTasks => 'Query my tasks';

  @override
  String get toolCallGetTaskDetail => 'Get task details';

  @override
  String get toolCallSearchTasks => 'Search tasks';

  @override
  String get toolCallGetMyProfile => 'Get my profile';

  @override
  String get toolCallGetPlatformFaq => 'Query FAQ';

  @override
  String get toolCallCheckCsAvailability => 'Check support online';

  @override
  String get toolCallGetMyPointsAndCoupons => 'Points & coupons';

  @override
  String get toolCallListActivities => 'Browse activities';

  @override
  String get toolCallGetMyNotificationsSummary => 'View notifications';

  @override
  String get toolCallListMyForumPosts => 'My forum posts';

  @override
  String get toolCallSearchFleaMarket => 'Search flea market';

  @override
  String get toolCallGetLeaderboardSummary => 'View leaderboard';

  @override
  String get toolCallListTaskExperts => 'Browse experts';

  @override
  String get toolCallLoadingQueryMyTasks => 'Checking your tasks…';

  @override
  String get toolCallLoadingGetTaskDetail => 'Fetching task details…';

  @override
  String get toolCallLoadingSearchTasks => 'Searching tasks…';

  @override
  String get toolCallLoadingGetMyProfile => 'Loading your profile…';

  @override
  String get toolCallLoadingGetPlatformFaq => 'Looking up FAQ…';

  @override
  String get toolCallLoadingCheckCsAvailability =>
      'Checking if support is online…';

  @override
  String get toolCallLoadingGetMyPointsAndCoupons =>
      'Loading points & coupons…';

  @override
  String get toolCallLoadingListActivities => 'Loading activities…';

  @override
  String get toolCallLoadingGetMyNotificationsSummary =>
      'Loading notifications…';

  @override
  String get toolCallLoadingListMyForumPosts => 'Loading your posts…';

  @override
  String get toolCallLoadingSearchFleaMarket => 'Searching flea market…';

  @override
  String get toolCallLoadingGetLeaderboardSummary => 'Loading leaderboard…';

  @override
  String get toolCallLoadingListTaskExperts => 'Loading experts…';

  @override
  String get toolCallGetMyWalletSummary => 'Wallet summary';

  @override
  String get toolCallGetMyMessagesSummary => 'Chat summary';

  @override
  String get toolCallGetMyVipStatus => 'VIP status';

  @override
  String get toolCallGetMyStudentVerification => 'Student verification';

  @override
  String get toolCallGetMyCheckinStatus => 'Check-in status';

  @override
  String get toolCallGetMyFleaMarketItems => 'My flea market';

  @override
  String get toolCallSearchForumPosts => 'Search forum';

  @override
  String get toolCallLoadingGetMyWalletSummary => 'Loading wallet info…';

  @override
  String get toolCallLoadingGetMyMessagesSummary => 'Loading chat summary…';

  @override
  String get toolCallLoadingGetMyVipStatus => 'Checking VIP status…';

  @override
  String get toolCallLoadingGetMyStudentVerification =>
      'Checking verification…';

  @override
  String get toolCallLoadingGetMyCheckinStatus => 'Checking check-in…';

  @override
  String get toolCallLoadingGetMyFleaMarketItems => 'Loading your items…';

  @override
  String get toolCallLoadingSearchForumPosts => 'Searching forum…';

  @override
  String get toolCallPrepareTaskDraft => 'Task draft';

  @override
  String get toolCallLoadingPrepareTaskDraft => 'Preparing task draft…';

  @override
  String get aiTaskDraftTitle => 'Task Draft';

  @override
  String get aiTaskDraftConfirmButton => 'Review & Publish';

  @override
  String get expertApplicationsTitle => 'Service Applications';

  @override
  String get expertApplicationsEmpty => 'No Applications';

  @override
  String get expertApplicationsEmptyMessage =>
      'You haven\'t received any service applications yet.';

  @override
  String get expertApplicationApprove => 'Approve';

  @override
  String get expertApplicationReject => 'Reject';

  @override
  String get expertApplicationCounterOffer => 'Counter Offer';

  @override
  String get expertApplicationApproved => 'Application approved successfully';

  @override
  String get expertApplicationRejected => 'Application rejected';

  @override
  String get expertApplicationCounterOfferSent => 'Counter offer sent';

  @override
  String get expertApplicationActionFailed =>
      'Operation failed, please try again';

  @override
  String get expertApplicationRejectReason => 'Reject Reason (Optional)';

  @override
  String get expertApplicationRejectReasonHint =>
      'Please enter the reason for rejection…';

  @override
  String get expertApplicationCounterPrice => 'Your Price';

  @override
  String get expertApplicationCounterPriceHint =>
      'Enter your counter offer price';

  @override
  String get expertApplicationCounterMessage => 'Message (Optional)';

  @override
  String get expertApplicationCounterMessageHint =>
      'Add a note about your counter offer…';

  @override
  String get expertApplicationConfirmApprove => 'Confirm Approve';

  @override
  String get expertApplicationConfirmApproveMessage =>
      'Are you sure you want to approve this application? A task and payment will be created.';

  @override
  String get expertApplicationConfirmReject => 'Confirm Reject';

  @override
  String get expertApplicationConfirmRejectMessage =>
      'Are you sure you want to reject this application?';

  @override
  String get expertApplicationStatusPending => 'Pending';

  @override
  String get expertApplicationStatusNegotiating => 'Negotiating';

  @override
  String get expertApplicationStatusPriceAgreed => 'Price Agreed';

  @override
  String get expertApplicationStatusApproved => 'Approved';

  @override
  String get expertApplicationStatusRejected => 'Rejected';

  @override
  String get expertApplicationStatusCancelled => 'Cancelled';

  @override
  String get expertApplicationApplicant => 'Applicant';

  @override
  String get expertApplicationService => 'Service';

  @override
  String get expertApplicationMessage => 'Message';

  @override
  String get expertApplicationPrice => 'Offered Price';

  @override
  String get expertApplicationBasePrice => 'Base Price';

  @override
  String get commonUnnamed => 'Unnamed';

  @override
  String commonImageUploadFailed(String error) {
    return 'Image upload failed: $error';
  }

  @override
  String commonImageCount(int current, int max) {
    return '$current/$max';
  }

  @override
  String get paymentCardSubtitle => 'Visa, Mastercard, AMEX';

  @override
  String get paymentWeChatPaySubtitle => 'WeChat Pay (Stripe)';

  @override
  String get paymentAlipaySubtitle => 'Alipay (Stripe)';

  @override
  String get commonCurrencySymbol => '£ ';

  @override
  String get forumDeletePostConfirm =>
      'Are you sure you want to delete this post? This action cannot be undone.';

  @override
  String get forumPostDeleted => 'Post deleted';

  @override
  String get forumPostUpdated => 'Post updated';

  @override
  String get forumReplyDeleted => 'Reply deleted';

  @override
  String get forumDeleteReplyConfirm =>
      'Are you sure you want to delete this reply?';

  @override
  String get fleaMarketDeleteItemConfirm =>
      'Are you sure you want to delete this listing? This action cannot be undone.';

  @override
  String get fleaMarketItemDeleted => 'Listing deleted';

  @override
  String get taskEvidenceTitle => 'Completion Evidence';

  @override
  String get taskEvidenceHint =>
      'You have completed this task. You may upload evidence images or add a text description (optional) for the poster to confirm.';

  @override
  String get taskEvidenceTextLabel => 'Text description (optional)';

  @override
  String get taskEvidenceTextHint => 'Describe what was done...';

  @override
  String get taskEvidenceImagesLabel => 'Evidence images (optional)';

  @override
  String get taskEvidenceImageLimit => 'Max 5MB per image, up to 5 images';

  @override
  String get taskEvidenceSubmit => 'Submit completion';

  @override
  String get taskEvidenceUploading => 'Uploading images...';

  @override
  String get stripeSetupRequired =>
      'Please set up your payout account before applying for tasks.';

  @override
  String get stripeSetupAction => 'Set up now';

  @override
  String get profileSendCode => 'Send Code';

  @override
  String get profileResendCode => 'Resend';

  @override
  String get profileCodeSentSuccess => 'Verification code sent';

  @override
  String get profileEmailCodeSent => 'Code sent to new email';

  @override
  String get profilePhoneCodeSent => 'Code sent to new phone';

  @override
  String profileCountdownSeconds(int seconds) {
    return '${seconds}s';
  }

  @override
  String get profileEmailRequired =>
      'Email is required to send verification code';

  @override
  String get profilePhoneRequired =>
      'Phone number is required to send verification code';

  @override
  String get profileEmailUnchanged => 'Please enter a different email address';

  @override
  String get profilePhoneUnchanged => 'Please enter a different phone number';

  @override
  String get profileEmailCodeRequired =>
      'Please enter the email verification code';

  @override
  String get profilePhoneCodeRequired =>
      'Please enter the phone verification code';

  @override
  String get profileNormalizePhoneHint => 'UK format: 07XXX or +44XXX';
}
