import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')
  ];

  /// No description provided for @commonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonGoSetup.
  ///
  /// In en, this message translates to:
  /// **'Go to setup'**
  String get commonGoSetup;

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonReport.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get commonReport;

  /// No description provided for @commonReportReason.
  ///
  /// In en, this message translates to:
  /// **'Please enter the reason for reporting'**
  String get commonReportReason;

  /// No description provided for @commonReportSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Report submitted'**
  String get commonReportSubmitted;

  /// No description provided for @commonCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy Link'**
  String get commonCopyLink;

  /// No description provided for @commonLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get commonLinkCopied;

  /// No description provided for @commonReload.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get commonReload;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get commonLoading;

  /// No description provided for @commonSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get commonSearch;

  /// No description provided for @commonClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get commonClear;

  /// No description provided for @commonSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get commonSubmit;

  /// No description provided for @commonSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Submitting...'**
  String get commonSubmitting;

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// No description provided for @commonNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get commonNext;

  /// No description provided for @commonFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get commonFinish;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @commonNotice.
  ///
  /// In en, this message translates to:
  /// **'Notice'**
  String get commonNotice;

  /// No description provided for @commonShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get commonShare;

  /// No description provided for @commonMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get commonMore;

  /// No description provided for @commonViewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get commonViewAll;

  /// No description provided for @commonLoadingImage.
  ///
  /// In en, this message translates to:
  /// **'Loading image...'**
  String get commonLoadingImage;

  /// No description provided for @commonAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get commonAll;

  /// No description provided for @commonFilter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get commonFilter;

  /// No description provided for @commonReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get commonReset;

  /// No description provided for @commonNotProvided.
  ///
  /// In en, this message translates to:
  /// **'Not provided'**
  String get commonNotProvided;

  /// No description provided for @commonPleaseSelect.
  ///
  /// In en, this message translates to:
  /// **'Please select'**
  String get commonPleaseSelect;

  /// No description provided for @commonUser.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get commonUser;

  /// No description provided for @commonUserWithId.
  ///
  /// In en, this message translates to:
  /// **'User {id}'**
  String commonUserWithId(String id);

  /// No description provided for @taskExpertWithId.
  ///
  /// In en, this message translates to:
  /// **'Expert {id}'**
  String taskExpertWithId(String id);

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Link²Ur'**
  String get appName;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Connect you and me, create value'**
  String get appTagline;

  /// No description provided for @appUser.
  ///
  /// In en, this message translates to:
  /// **'Link²Ur User'**
  String get appUser;

  /// No description provided for @appTermsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get appTermsOfService;

  /// No description provided for @appPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get appPrivacyPolicy;

  /// No description provided for @appAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get appAbout;

  /// No description provided for @appVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get appVersion;

  /// No description provided for @authLogin.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get authLogin;

  /// No description provided for @authRegister.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get authRegister;

  /// No description provided for @authLogout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get authLogout;

  /// No description provided for @authSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Your session has expired, please log in again'**
  String get authSessionExpired;

  /// No description provided for @authForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password'**
  String get authForgotPassword;

  /// No description provided for @authEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmail;

  /// No description provided for @authEmailOrId.
  ///
  /// In en, this message translates to:
  /// **'Email/ID'**
  String get authEmailOrId;

  /// No description provided for @authPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPassword;

  /// No description provided for @authPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get authPhone;

  /// No description provided for @authVerificationCode.
  ///
  /// In en, this message translates to:
  /// **'Verification Code'**
  String get authVerificationCode;

  /// No description provided for @authLoginLater.
  ///
  /// In en, this message translates to:
  /// **'Login Later'**
  String get authLoginLater;

  /// No description provided for @authCountdownSeconds.
  ///
  /// In en, this message translates to:
  /// **'{param1} seconds'**
  String authCountdownSeconds(int param1);

  /// No description provided for @loginRequired.
  ///
  /// In en, this message translates to:
  /// **'Login Required'**
  String get loginRequired;

  /// No description provided for @loginRequiredForPoints.
  ///
  /// In en, this message translates to:
  /// **'Please login to view points and coupons'**
  String get loginRequiredForPoints;

  /// No description provided for @loginRequiredForVerification.
  ///
  /// In en, this message translates to:
  /// **'Please login to verify student status'**
  String get loginRequiredForVerification;

  /// No description provided for @loginLoginNow.
  ///
  /// In en, this message translates to:
  /// **'Login Now'**
  String get loginLoginNow;

  /// No description provided for @authSendCode.
  ///
  /// In en, this message translates to:
  /// **'Send Code'**
  String get authSendCode;

  /// No description provided for @authResendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend Code'**
  String get authResendCode;

  /// No description provided for @authLoginMethod.
  ///
  /// In en, this message translates to:
  /// **'Login Method'**
  String get authLoginMethod;

  /// No description provided for @authEmailPassword.
  ///
  /// In en, this message translates to:
  /// **'Email/ID & Password'**
  String get authEmailPassword;

  /// No description provided for @authEmailCode.
  ///
  /// In en, this message translates to:
  /// **'Email Code'**
  String get authEmailCode;

  /// No description provided for @authPhoneCode.
  ///
  /// In en, this message translates to:
  /// **'Phone Verification'**
  String get authPhoneCode;

  /// No description provided for @authEnterEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter email'**
  String get authEnterEmail;

  /// No description provided for @authEnterEmailOrId.
  ///
  /// In en, this message translates to:
  /// **'Enter email or ID'**
  String get authEnterEmailOrId;

  /// No description provided for @authEnterPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter password'**
  String get authEnterPassword;

  /// No description provided for @authEnterPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter phone number'**
  String get authEnterPhone;

  /// No description provided for @authEnterCode.
  ///
  /// In en, this message translates to:
  /// **'Enter verification code'**
  String get authEnterCode;

  /// No description provided for @authNoAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get authNoAccount;

  /// No description provided for @authHasAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get authHasAccount;

  /// No description provided for @authRegisterNow.
  ///
  /// In en, this message translates to:
  /// **'Register Now'**
  String get authRegisterNow;

  /// No description provided for @authLoginNow.
  ///
  /// In en, this message translates to:
  /// **'Login Now'**
  String get authLoginNow;

  /// No description provided for @authNoAccountUseCode.
  ///
  /// In en, this message translates to:
  /// **'Login with verification code'**
  String get authNoAccountUseCode;

  /// No description provided for @authRegisterSuccess.
  ///
  /// In en, this message translates to:
  /// **'Registration Successful'**
  String get authRegisterSuccess;

  /// No description provided for @authCaptchaTitle.
  ///
  /// In en, this message translates to:
  /// **'Verification'**
  String get authCaptchaTitle;

  /// No description provided for @authCaptchaMessage.
  ///
  /// In en, this message translates to:
  /// **'Please complete the verification'**
  String get authCaptchaMessage;

  /// No description provided for @authCaptchaError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load verification, please try again later'**
  String get authCaptchaError;

  /// No description provided for @authUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get authUsername;

  /// No description provided for @authEnterUsername.
  ///
  /// In en, this message translates to:
  /// **'Enter username'**
  String get authEnterUsername;

  /// No description provided for @authPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters, including letters and numbers'**
  String get authPasswordHint;

  /// No description provided for @authPhoneOptional.
  ///
  /// In en, this message translates to:
  /// **'Phone (Optional)'**
  String get authPhoneOptional;

  /// No description provided for @authInvitationCodeOptional.
  ///
  /// In en, this message translates to:
  /// **'Invite Code / Inviter ID (Optional)'**
  String get authInvitationCodeOptional;

  /// No description provided for @authInvitationCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Enter invite code or 8-digit user ID'**
  String get authInvitationCodeHint;

  /// No description provided for @authAgreeToTerms.
  ///
  /// In en, this message translates to:
  /// **'I have read and agree to the'**
  String get authAgreeToTerms;

  /// No description provided for @authTermsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get authTermsOfService;

  /// No description provided for @authPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get authPrivacyPolicy;

  /// No description provided for @homeExperts.
  ///
  /// In en, this message translates to:
  /// **'Experts'**
  String get homeExperts;

  /// No description provided for @homeRecommended.
  ///
  /// In en, this message translates to:
  /// **'Link²Ur'**
  String get homeRecommended;

  /// No description provided for @homeNearby.
  ///
  /// In en, this message translates to:
  /// **'Nearby'**
  String get homeNearby;

  /// No description provided for @homeGreeting.
  ///
  /// In en, this message translates to:
  /// **'Hello, {param1}'**
  String homeGreeting(String param1);

  /// Home page greeting prompt for suggested actions
  ///
  /// In en, this message translates to:
  /// **'What would you like to do today?'**
  String get homeWhatToDo;

  /// No description provided for @homeMenu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get homeMenu;

  /// No description provided for @homeSearchExperts.
  ///
  /// In en, this message translates to:
  /// **'Search Experts'**
  String get homeSearchExperts;

  /// No description provided for @homeSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get homeSearch;

  /// No description provided for @homeNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get homeNoResults;

  /// No description provided for @homeTryOtherKeywords.
  ///
  /// In en, this message translates to:
  /// **'Try other keywords'**
  String get homeTryOtherKeywords;

  /// No description provided for @homeSearchHistory.
  ///
  /// In en, this message translates to:
  /// **'Search History'**
  String get homeSearchHistory;

  /// No description provided for @homeHotSearches.
  ///
  /// In en, this message translates to:
  /// **'Hot Searches'**
  String get homeHotSearches;

  /// No description provided for @homeNoNearbyTasks.
  ///
  /// In en, this message translates to:
  /// **'No nearby tasks'**
  String get homeNoNearbyTasks;

  /// No description provided for @homeNoNearbyTasksMessage.
  ///
  /// In en, this message translates to:
  /// **'No tasks have been posted nearby yet. Be the first to post one!'**
  String get homeNoNearbyTasksMessage;

  /// No description provided for @homeNoExperts.
  ///
  /// In en, this message translates to:
  /// **'No task experts'**
  String get homeNoExperts;

  /// No description provided for @homeNoExpertsMessage.
  ///
  /// In en, this message translates to:
  /// **'No task experts yet, stay tuned...'**
  String get homeNoExpertsMessage;

  /// No description provided for @homeRecommendedTasks.
  ///
  /// In en, this message translates to:
  /// **'Recommended Tasks'**
  String get homeRecommendedTasks;

  /// No description provided for @homeRecommendedBadge.
  ///
  /// In en, this message translates to:
  /// **'Pick'**
  String get homeRecommendedBadge;

  /// No description provided for @homeMemberPublished.
  ///
  /// In en, this message translates to:
  /// **'Member Published'**
  String get homeMemberPublished;

  /// No description provided for @homeMemberSeller.
  ///
  /// In en, this message translates to:
  /// **'Member Seller'**
  String get homeMemberSeller;

  /// No description provided for @homeNoRecommendedTasks.
  ///
  /// In en, this message translates to:
  /// **'No recommended tasks'**
  String get homeNoRecommendedTasks;

  /// No description provided for @homeNoRecommendedTasksMessage.
  ///
  /// In en, this message translates to:
  /// **'No recommended tasks yet. Check out the task hall!'**
  String get homeNoRecommendedTasksMessage;

  /// No description provided for @homeLatestActivity.
  ///
  /// In en, this message translates to:
  /// **'Latest Activity'**
  String get homeLatestActivity;

  /// No description provided for @homeNoActivity.
  ///
  /// In en, this message translates to:
  /// **'No activity'**
  String get homeNoActivity;

  /// No description provided for @homeNoActivityMessage.
  ///
  /// In en, this message translates to:
  /// **'No latest activity yet'**
  String get homeNoActivityMessage;

  /// No description provided for @homeNoMoreActivity.
  ///
  /// In en, this message translates to:
  /// **'Above are the latest activities'**
  String get homeNoMoreActivity;

  /// No description provided for @homeLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load More'**
  String get homeLoadMore;

  /// No description provided for @homeHotEvents.
  ///
  /// In en, this message translates to:
  /// **'Hot Events'**
  String get homeHotEvents;

  /// No description provided for @homeNoEvents.
  ///
  /// In en, this message translates to:
  /// **'No events'**
  String get homeNoEvents;

  /// No description provided for @homeNoEventsMessage.
  ///
  /// In en, this message translates to:
  /// **'No events at the moment, stay tuned...'**
  String get homeNoEventsMessage;

  /// No description provided for @homeViewEvent.
  ///
  /// In en, this message translates to:
  /// **'View Event'**
  String get homeViewEvent;

  /// No description provided for @homeTapToViewEvents.
  ///
  /// In en, this message translates to:
  /// **'Tap to view latest events'**
  String get homeTapToViewEvents;

  /// No description provided for @homeMultiplePeople.
  ///
  /// In en, this message translates to:
  /// **'Multiple People'**
  String get homeMultiplePeople;

  /// No description provided for @homeView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get homeView;

  /// No description provided for @tasksTaskDetail.
  ///
  /// In en, this message translates to:
  /// **'Task Details'**
  String get tasksTaskDetail;

  /// No description provided for @tasksLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load'**
  String get tasksLoadFailed;

  /// No description provided for @tasksCancelTask.
  ///
  /// In en, this message translates to:
  /// **'Cancel Task'**
  String get tasksCancelTask;

  /// No description provided for @tasksCancelTaskConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to cancel this task?'**
  String get tasksCancelTaskConfirm;

  /// No description provided for @tasksApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get tasksApply;

  /// No description provided for @tasksApplyTask.
  ///
  /// In en, this message translates to:
  /// **'Apply for Task'**
  String get tasksApplyTask;

  /// No description provided for @tasksApplyMessage.
  ///
  /// In en, this message translates to:
  /// **'Message (Optional)'**
  String get tasksApplyMessage;

  /// No description provided for @tasksApplyInfo.
  ///
  /// In en, this message translates to:
  /// **'Application Info'**
  String get tasksApplyInfo;

  /// No description provided for @tasksPriceNegotiation.
  ///
  /// In en, this message translates to:
  /// **'Price Negotiation'**
  String get tasksPriceNegotiation;

  /// No description provided for @tasksApplyHint.
  ///
  /// In en, this message translates to:
  /// **'Explain your application reason to the publisher to improve success rate'**
  String get tasksApplyHint;

  /// No description provided for @tasksSubmitApplication.
  ///
  /// In en, this message translates to:
  /// **'Submit Application'**
  String get tasksSubmitApplication;

  /// No description provided for @tasksNoApplicants.
  ///
  /// In en, this message translates to:
  /// **'No applicants'**
  String get tasksNoApplicants;

  /// No description provided for @tasksApplicantsList.
  ///
  /// In en, this message translates to:
  /// **'Applicants List ({param1})'**
  String tasksApplicantsList(int param1);

  /// No description provided for @tasksMessageLabel.
  ///
  /// In en, this message translates to:
  /// **'Message: {param1}'**
  String tasksMessageLabel(String param1);

  /// No description provided for @tasksTaskDescription.
  ///
  /// In en, this message translates to:
  /// **'Task Description'**
  String get tasksTaskDescription;

  /// No description provided for @tasksTimeInfo.
  ///
  /// In en, this message translates to:
  /// **'Time Information'**
  String get tasksTimeInfo;

  /// No description provided for @tasksPublishTime.
  ///
  /// In en, this message translates to:
  /// **'Publish Time'**
  String get tasksPublishTime;

  /// No description provided for @tasksDeadline.
  ///
  /// In en, this message translates to:
  /// **'Deadline'**
  String get tasksDeadline;

  /// No description provided for @tasksPublisher.
  ///
  /// In en, this message translates to:
  /// **'Publisher'**
  String get tasksPublisher;

  /// No description provided for @tasksYourTask.
  ///
  /// In en, this message translates to:
  /// **'This is your task'**
  String get tasksYourTask;

  /// No description provided for @tasksManageTask.
  ///
  /// In en, this message translates to:
  /// **'You can view applicants and manage the task below'**
  String get tasksManageTask;

  /// No description provided for @tasksReviews.
  ///
  /// In en, this message translates to:
  /// **'Reviews ({param1})'**
  String tasksReviews(int param1);

  /// No description provided for @tasksNoTaskImages.
  ///
  /// In en, this message translates to:
  /// **'No task images'**
  String get tasksNoTaskImages;

  /// No description provided for @tasksPointsReward.
  ///
  /// In en, this message translates to:
  /// **'{param1} Points'**
  String tasksPointsReward(int param1);

  /// No description provided for @tasksShareTo.
  ///
  /// In en, this message translates to:
  /// **'Share to...'**
  String get tasksShareTo;

  /// No description provided for @tasksTask.
  ///
  /// In en, this message translates to:
  /// **'Task'**
  String get tasksTask;

  /// No description provided for @tasksTasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get tasksTasks;

  /// No description provided for @tasksNotInterested.
  ///
  /// In en, this message translates to:
  /// **'Not Interested'**
  String get tasksNotInterested;

  /// No description provided for @tasksMarkNotInterestedConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to mark this task as not interested?'**
  String get tasksMarkNotInterestedConfirm;

  /// No description provided for @tasksMyTasks.
  ///
  /// In en, this message translates to:
  /// **'My Tasks'**
  String get tasksMyTasks;

  /// No description provided for @expertsExperts.
  ///
  /// In en, this message translates to:
  /// **'Task Experts'**
  String get expertsExperts;

  /// No description provided for @expertsBecomeExpert.
  ///
  /// In en, this message translates to:
  /// **'Become an Expert'**
  String get expertsBecomeExpert;

  /// No description provided for @expertsSearchExperts.
  ///
  /// In en, this message translates to:
  /// **'Search Task Experts'**
  String get expertsSearchExperts;

  /// No description provided for @expertsApplyNow.
  ///
  /// In en, this message translates to:
  /// **'Apply Now'**
  String get expertsApplyNow;

  /// No description provided for @expertsLoginToApply.
  ///
  /// In en, this message translates to:
  /// **'Login to Apply'**
  String get expertsLoginToApply;

  /// No description provided for @forumForum.
  ///
  /// In en, this message translates to:
  /// **'Forum'**
  String get forumForum;

  /// No description provided for @forumAllPosts.
  ///
  /// In en, this message translates to:
  /// **'All Posts'**
  String get forumAllPosts;

  /// No description provided for @forumNoPosts.
  ///
  /// In en, this message translates to:
  /// **'No Posts'**
  String get forumNoPosts;

  /// No description provided for @forumNoPostsMessage.
  ///
  /// In en, this message translates to:
  /// **'There are no posts yet. Be the first to post!'**
  String get forumNoPostsMessage;

  /// No description provided for @forumSearchPosts.
  ///
  /// In en, this message translates to:
  /// **'Search posts...'**
  String get forumSearchPosts;

  /// No description provided for @forumPosts.
  ///
  /// In en, this message translates to:
  /// **'Posts'**
  String get forumPosts;

  /// No description provided for @forumPostLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load post'**
  String get forumPostLoadFailed;

  /// No description provided for @forumOfficial.
  ///
  /// In en, this message translates to:
  /// **'Official'**
  String get forumOfficial;

  /// No description provided for @forumAllReplies.
  ///
  /// In en, this message translates to:
  /// **'All Comments'**
  String get forumAllReplies;

  /// No description provided for @forumReply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get forumReply;

  /// No description provided for @forumReplyTo.
  ///
  /// In en, this message translates to:
  /// **'Reply to'**
  String get forumReplyTo;

  /// No description provided for @forumWriteReply.
  ///
  /// In en, this message translates to:
  /// **'Write your reply...'**
  String get forumWriteReply;

  /// No description provided for @forumSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get forumSend;

  /// No description provided for @forumView.
  ///
  /// In en, this message translates to:
  /// **'Views'**
  String get forumView;

  /// No description provided for @forumLike.
  ///
  /// In en, this message translates to:
  /// **'Likes'**
  String get forumLike;

  /// No description provided for @forumFavorite.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get forumFavorite;

  /// No description provided for @fleaMarketFleaMarket.
  ///
  /// In en, this message translates to:
  /// **'Flea Market'**
  String get fleaMarketFleaMarket;

  /// No description provided for @fleaMarketSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Discover great items, sell your unused goods'**
  String get fleaMarketSubtitle;

  /// No description provided for @fleaMarketNoItems.
  ///
  /// In en, this message translates to:
  /// **'No items'**
  String get fleaMarketNoItems;

  /// No description provided for @fleaMarketNoItemsMessage.
  ///
  /// In en, this message translates to:
  /// **'The flea market has no items yet. Be the first to post one!'**
  String get fleaMarketNoItemsMessage;

  /// No description provided for @fleaMarketSearchItems.
  ///
  /// In en, this message translates to:
  /// **'Search items'**
  String get fleaMarketSearchItems;

  /// No description provided for @fleaMarketItems.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get fleaMarketItems;

  /// No description provided for @fleaMarketCategory.
  ///
  /// In en, this message translates to:
  /// **'Product Category'**
  String get fleaMarketCategory;

  /// No description provided for @fleaMarketProductImages.
  ///
  /// In en, this message translates to:
  /// **'Product Images'**
  String get fleaMarketProductImages;

  /// No description provided for @fleaMarketAddImage.
  ///
  /// In en, this message translates to:
  /// **'Add Image'**
  String get fleaMarketAddImage;

  /// No description provided for @fleaMarketProductInfo.
  ///
  /// In en, this message translates to:
  /// **'Product Information'**
  String get fleaMarketProductInfo;

  /// No description provided for @fleaMarketProductTitle.
  ///
  /// In en, this message translates to:
  /// **'Product Title'**
  String get fleaMarketProductTitle;

  /// No description provided for @fleaMarketProductTitlePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Enter product title'**
  String get fleaMarketProductTitlePlaceholder;

  /// No description provided for @fleaMarketDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get fleaMarketDescription;

  /// No description provided for @fleaMarketDescriptionPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Describe your product in detail'**
  String get fleaMarketDescriptionPlaceholder;

  /// No description provided for @fleaMarketPrice.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get fleaMarketPrice;

  /// No description provided for @fleaMarketContact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get fleaMarketContact;

  /// No description provided for @fleaMarketContactPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Enter contact information'**
  String get fleaMarketContactPlaceholder;

  /// No description provided for @fleaMarketNoImage.
  ///
  /// In en, this message translates to:
  /// **'No Image'**
  String get fleaMarketNoImage;

  /// No description provided for @fleaMarketTransactionLocation.
  ///
  /// In en, this message translates to:
  /// **'Transaction Location'**
  String get fleaMarketTransactionLocation;

  /// No description provided for @fleaMarketOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get fleaMarketOnline;

  /// No description provided for @profileProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileProfile;

  /// No description provided for @profileMyTasks.
  ///
  /// In en, this message translates to:
  /// **'My Tasks'**
  String get profileMyTasks;

  /// No description provided for @profileMyPosts.
  ///
  /// In en, this message translates to:
  /// **'My Items'**
  String get profileMyPosts;

  /// No description provided for @profileSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get profileSettings;

  /// No description provided for @profileAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get profileAbout;

  /// No description provided for @profileLogout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get profileLogout;

  /// No description provided for @profileLogoutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to logout?'**
  String get profileLogoutConfirm;

  /// No description provided for @profilePleaseUpdateEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Please Update Email'**
  String get profilePleaseUpdateEmailTitle;

  /// No description provided for @profilePleaseUpdateEmailMessage.
  ///
  /// In en, this message translates to:
  /// **'Please update your email address in Settings to avoid missing important notifications.'**
  String get profilePleaseUpdateEmailMessage;

  /// No description provided for @profileName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get profileName;

  /// No description provided for @profileEnterName.
  ///
  /// In en, this message translates to:
  /// **'Enter name'**
  String get profileEnterName;

  /// No description provided for @profileEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get profileEmail;

  /// No description provided for @profileEnterEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter email'**
  String get profileEnterEmail;

  /// No description provided for @profileEnterNewEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter new email'**
  String get profileEnterNewEmail;

  /// No description provided for @profileVerificationCode.
  ///
  /// In en, this message translates to:
  /// **'Verification Code'**
  String get profileVerificationCode;

  /// No description provided for @profileEnterVerificationCode.
  ///
  /// In en, this message translates to:
  /// **'Enter verification code'**
  String get profileEnterVerificationCode;

  /// No description provided for @profilePhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get profilePhone;

  /// No description provided for @profileEnterPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter phone number'**
  String get profileEnterPhone;

  /// No description provided for @profileEnterNewPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter new phone number'**
  String get profileEnterNewPhone;

  /// No description provided for @profileClickToChangeAvatar.
  ///
  /// In en, this message translates to:
  /// **'Tap camera icon to change avatar'**
  String get profileClickToChangeAvatar;

  /// No description provided for @profileEditProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get profileEditProfile;

  /// No description provided for @profileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile Updated'**
  String get profileUpdated;

  /// No description provided for @messagesMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get messagesMessages;

  /// No description provided for @messagesChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get messagesChat;

  /// No description provided for @messagesSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get messagesSend;

  /// No description provided for @messagesEnterMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter message...'**
  String get messagesEnterMessage;

  /// No description provided for @leaderboardLeaderboard.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get leaderboardLeaderboard;

  /// No description provided for @leaderboardRank.
  ///
  /// In en, this message translates to:
  /// **'Rank'**
  String get leaderboardRank;

  /// No description provided for @leaderboardPoints.
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get leaderboardPoints;

  /// No description provided for @leaderboardUser.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get leaderboardUser;

  /// No description provided for @leaderboardLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load leaderboard'**
  String get leaderboardLoadFailed;

  /// No description provided for @leaderboardSortComprehensive.
  ///
  /// In en, this message translates to:
  /// **'Comprehensive'**
  String get leaderboardSortComprehensive;

  /// No description provided for @leaderboardSortNetVotes.
  ///
  /// In en, this message translates to:
  /// **'Net Votes'**
  String get leaderboardSortNetVotes;

  /// No description provided for @leaderboardSortUpvotes.
  ///
  /// In en, this message translates to:
  /// **'Upvotes'**
  String get leaderboardSortUpvotes;

  /// No description provided for @leaderboardSortLatest.
  ///
  /// In en, this message translates to:
  /// **'Latest'**
  String get leaderboardSortLatest;

  /// No description provided for @leaderboardNoItems.
  ///
  /// In en, this message translates to:
  /// **'No Leaderboards'**
  String get leaderboardNoItems;

  /// No description provided for @leaderboardNoItemsMessage.
  ///
  /// In en, this message translates to:
  /// **'This leaderboard has no participants yet. Be the first to submit!'**
  String get leaderboardNoItemsMessage;

  /// No description provided for @leaderboardItemCount.
  ///
  /// In en, this message translates to:
  /// **'Entries'**
  String get leaderboardItemCount;

  /// No description provided for @leaderboardTotalVotes.
  ///
  /// In en, this message translates to:
  /// **'Total Votes'**
  String get leaderboardTotalVotes;

  /// No description provided for @leaderboardViewCount.
  ///
  /// In en, this message translates to:
  /// **'Views'**
  String get leaderboardViewCount;

  /// No description provided for @leaderboardItemLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load item'**
  String get leaderboardItemLoadFailed;

  /// No description provided for @leaderboardSubmittedBy.
  ///
  /// In en, this message translates to:
  /// **'Submitted by {param1}'**
  String leaderboardSubmittedBy(String param1);

  /// No description provided for @leaderboardItemDetail.
  ///
  /// In en, this message translates to:
  /// **'Item Detail'**
  String get leaderboardItemDetail;

  /// No description provided for @leaderboardNoDescription.
  ///
  /// In en, this message translates to:
  /// **'No description available'**
  String get leaderboardNoDescription;

  /// No description provided for @leaderboardContactLocation.
  ///
  /// In en, this message translates to:
  /// **'Contact & Location'**
  String get leaderboardContactLocation;

  /// No description provided for @leaderboardCurrentScore.
  ///
  /// In en, this message translates to:
  /// **'Current Score'**
  String get leaderboardCurrentScore;

  /// No description provided for @leaderboardTotalVotesCount.
  ///
  /// In en, this message translates to:
  /// **'Total Votes'**
  String get leaderboardTotalVotesCount;

  /// No description provided for @leaderboardFeaturedComments.
  ///
  /// In en, this message translates to:
  /// **'Featured Comments'**
  String get leaderboardFeaturedComments;

  /// No description provided for @leaderboardNoComments.
  ///
  /// In en, this message translates to:
  /// **'No comments yet, share your thoughts!'**
  String get leaderboardNoComments;

  /// No description provided for @leaderboardOppose.
  ///
  /// In en, this message translates to:
  /// **'Oppose'**
  String get leaderboardOppose;

  /// No description provided for @leaderboardSupport.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get leaderboardSupport;

  /// No description provided for @leaderboardNoImages.
  ///
  /// In en, this message translates to:
  /// **'No Images'**
  String get leaderboardNoImages;

  /// No description provided for @leaderboardWriteReason.
  ///
  /// In en, this message translates to:
  /// **'Write your reason for others to reference...'**
  String get leaderboardWriteReason;

  /// No description provided for @leaderboardAnonymousVote.
  ///
  /// In en, this message translates to:
  /// **'Anonymous Vote'**
  String get leaderboardAnonymousVote;

  /// No description provided for @leaderboardSubmitVote.
  ///
  /// In en, this message translates to:
  /// **'Submit Vote'**
  String get leaderboardSubmitVote;

  /// No description provided for @leaderboardAddImage.
  ///
  /// In en, this message translates to:
  /// **'Add Image'**
  String get leaderboardAddImage;

  /// No description provided for @leaderboardApplyNew.
  ///
  /// In en, this message translates to:
  /// **'Apply for New Leaderboard'**
  String get leaderboardApplyNew;

  /// No description provided for @leaderboardSupportReason.
  ///
  /// In en, this message translates to:
  /// **'Support Reason'**
  String get leaderboardSupportReason;

  /// No description provided for @leaderboardOpposeReason.
  ///
  /// In en, this message translates to:
  /// **'Oppose Reason'**
  String get leaderboardOpposeReason;

  /// No description provided for @leaderboardAnonymousUser.
  ///
  /// In en, this message translates to:
  /// **'Anonymous User'**
  String get leaderboardAnonymousUser;

  /// No description provided for @leaderboardConfirmSupport.
  ///
  /// In en, this message translates to:
  /// **'Confirm Support'**
  String get leaderboardConfirmSupport;

  /// No description provided for @leaderboardConfirmOppose.
  ///
  /// In en, this message translates to:
  /// **'Confirm Oppose'**
  String get leaderboardConfirmOppose;

  /// No description provided for @leaderboardCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get leaderboardCopied;

  /// No description provided for @leaderboardComments.
  ///
  /// In en, this message translates to:
  /// **'Vote Comments'**
  String get leaderboardComments;

  /// No description provided for @leaderboardContactInfoDetail.
  ///
  /// In en, this message translates to:
  /// **'Contact Info'**
  String get leaderboardContactInfoDetail;

  /// No description provided for @leaderboardNetScore.
  ///
  /// In en, this message translates to:
  /// **'Net Score'**
  String get leaderboardNetScore;

  /// No description provided for @leaderboardBasicInfo.
  ///
  /// In en, this message translates to:
  /// **'Basic Information'**
  String get leaderboardBasicInfo;

  /// No description provided for @leaderboardContactInfo.
  ///
  /// In en, this message translates to:
  /// **'Contact Information (Optional)'**
  String get leaderboardContactInfo;

  /// No description provided for @leaderboardImageDisplay.
  ///
  /// In en, this message translates to:
  /// **'Image Display (Optional)'**
  String get leaderboardImageDisplay;

  /// No description provided for @leaderboardItemName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get leaderboardItemName;

  /// No description provided for @leaderboardItemDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get leaderboardItemDescription;

  /// No description provided for @leaderboardItemAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get leaderboardItemAddress;

  /// No description provided for @leaderboardItemPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get leaderboardItemPhone;

  /// No description provided for @leaderboardItemWebsite.
  ///
  /// In en, this message translates to:
  /// **'Official Website'**
  String get leaderboardItemWebsite;

  /// No description provided for @leaderboardSubmitItem.
  ///
  /// In en, this message translates to:
  /// **'Submit Entry'**
  String get leaderboardSubmitItem;

  /// No description provided for @leaderboardSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Submitting...'**
  String get leaderboardSubmitting;

  /// No description provided for @leaderboardNamePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'e.g., Most Popular Chinese Restaurant'**
  String get leaderboardNamePlaceholder;

  /// No description provided for @leaderboardDescriptionPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Please describe the purpose and inclusion criteria of this leaderboard...'**
  String get leaderboardDescriptionPlaceholder;

  /// No description provided for @leaderboardAddressPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Please enter detailed address'**
  String get leaderboardAddressPlaceholder;

  /// No description provided for @leaderboardPhonePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Please enter phone number'**
  String get leaderboardPhonePlaceholder;

  /// No description provided for @leaderboardWebsitePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Please enter website address'**
  String get leaderboardWebsitePlaceholder;

  /// No description provided for @leaderboardPleaseEnterItemName.
  ///
  /// In en, this message translates to:
  /// **'Please enter item name'**
  String get leaderboardPleaseEnterItemName;

  /// No description provided for @activityPerson.
  ///
  /// In en, this message translates to:
  /// **'person'**
  String get activityPerson;

  /// No description provided for @activityPersonsBooked.
  ///
  /// In en, this message translates to:
  /// **'persons booked'**
  String get activityPersonsBooked;

  /// No description provided for @taskExpertServicesCount.
  ///
  /// In en, this message translates to:
  /// **'{param1} services'**
  String taskExpertServicesCount(int param1);

  /// No description provided for @taskExpertCompletionRate.
  ///
  /// In en, this message translates to:
  /// **'Completion Rate'**
  String get taskExpertCompletionRate;

  /// No description provided for @taskExpertNoServices.
  ///
  /// In en, this message translates to:
  /// **'No Services'**
  String get taskExpertNoServices;

  /// No description provided for @taskExpertOrder.
  ///
  /// In en, this message translates to:
  /// **'order'**
  String get taskExpertOrder;

  /// No description provided for @taskExpertCompletionRatePercent.
  ///
  /// In en, this message translates to:
  /// **'{param1}% Completion Rate'**
  String taskExpertCompletionRatePercent(int param1);

  /// No description provided for @taskExpertSearchExperts.
  ///
  /// In en, this message translates to:
  /// **'Search Task Experts'**
  String get taskExpertSearchExperts;

  /// No description provided for @taskExpertNoExpertsFound.
  ///
  /// In en, this message translates to:
  /// **'No experts found'**
  String get taskExpertNoExpertsFound;

  /// No description provided for @taskExpertNoExpertsFoundMessage.
  ///
  /// In en, this message translates to:
  /// **'Try adjusting filter conditions'**
  String get taskExpertNoExpertsFoundMessage;

  /// No description provided for @taskExpertNoExpertsFoundWithQuery.
  ///
  /// In en, this message translates to:
  /// **'No experts found matching your search'**
  String get taskExpertNoExpertsFoundWithQuery;

  /// No description provided for @taskExpertSearchTitle.
  ///
  /// In en, this message translates to:
  /// **'Search experts'**
  String get taskExpertSearchTitle;

  /// No description provided for @taskExpertAllTypes.
  ///
  /// In en, this message translates to:
  /// **'All Types'**
  String get taskExpertAllTypes;

  /// No description provided for @taskExpertType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get taskExpertType;

  /// No description provided for @taskExpertLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get taskExpertLocation;

  /// No description provided for @taskExpertAllCities.
  ///
  /// In en, this message translates to:
  /// **'All Cities'**
  String get taskExpertAllCities;

  /// No description provided for @taskExpertRating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get taskExpertRating;

  /// No description provided for @taskExpertCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get taskExpertCompleted;

  /// No description provided for @serviceLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get serviceLoading;

  /// No description provided for @serviceLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load service information'**
  String get serviceLoadFailed;

  /// No description provided for @serviceNeedDescription.
  ///
  /// In en, this message translates to:
  /// **'Briefly describe your needs to help the expert understand...'**
  String get serviceNeedDescription;

  /// No description provided for @locationGoogleMaps.
  ///
  /// In en, this message translates to:
  /// **'Google Maps'**
  String get locationGoogleMaps;

  /// No description provided for @webviewWebPage.
  ///
  /// In en, this message translates to:
  /// **'Web Page'**
  String get webviewWebPage;

  /// No description provided for @webviewLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get webviewLoading;

  /// No description provided for @webviewDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get webviewDone;

  /// No description provided for @profileRecentTasks.
  ///
  /// In en, this message translates to:
  /// **'Recent Tasks'**
  String get profileRecentTasks;

  /// No description provided for @profileUserReviews.
  ///
  /// In en, this message translates to:
  /// **'User Reviews'**
  String get profileUserReviews;

  /// No description provided for @profileJoinedDays.
  ///
  /// In en, this message translates to:
  /// **'Joined {param1} days ago'**
  String profileJoinedDays(int param1);

  /// No description provided for @profileReward.
  ///
  /// In en, this message translates to:
  /// **'Reward'**
  String get profileReward;

  /// No description provided for @profileSelectAvatar.
  ///
  /// In en, this message translates to:
  /// **'Select Avatar'**
  String get profileSelectAvatar;

  /// No description provided for @locationTitle.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get locationTitle;

  /// No description provided for @locationSearchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search location or enter Online'**
  String get locationSearchPlaceholder;

  /// No description provided for @locationGettingAddress.
  ///
  /// In en, this message translates to:
  /// **'Getting address...'**
  String get locationGettingAddress;

  /// No description provided for @locationDragToSelect.
  ///
  /// In en, this message translates to:
  /// **'Drag map to select location'**
  String get locationDragToSelect;

  /// No description provided for @locationCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Current Location'**
  String get locationCurrentLocation;

  /// No description provided for @locationOnlineRemote.
  ///
  /// In en, this message translates to:
  /// **'Online/Remote'**
  String get locationOnlineRemote;

  /// No description provided for @locationSelectTitle.
  ///
  /// In en, this message translates to:
  /// **'Select location'**
  String get locationSelectTitle;

  /// No description provided for @locationSearchPlace.
  ///
  /// In en, this message translates to:
  /// **'Search place, address, postcode...'**
  String get locationSearchPlace;

  /// No description provided for @locationMoving.
  ///
  /// In en, this message translates to:
  /// **'Moving'**
  String get locationMoving;

  /// No description provided for @searchResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'Search results'**
  String get searchResultsTitle;

  /// No description provided for @taskExpertLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get taskExpertLoading;

  /// No description provided for @taskExpertLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load expert info'**
  String get taskExpertLoadFailed;

  /// No description provided for @externalWebLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get externalWebLoading;

  /// No description provided for @emptyStateNoContent.
  ///
  /// In en, this message translates to:
  /// **'No content yet'**
  String get emptyStateNoContent;

  /// No description provided for @emptyStateNoContentMessage.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet. Try refreshing or come back later.'**
  String get emptyStateNoContentMessage;

  /// No description provided for @emptyStateNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get emptyStateNoResults;

  /// No description provided for @emptyStateNoResultsMessage.
  ///
  /// In en, this message translates to:
  /// **'No matching search results. Try other keywords.'**
  String get emptyStateNoResultsMessage;

  /// No description provided for @leaderboardEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No leaderboard yet'**
  String get leaderboardEmptyTitle;

  /// No description provided for @leaderboardEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Be the first to create one!'**
  String get leaderboardEmptyMessage;

  /// No description provided for @leaderboardSortHot.
  ///
  /// In en, this message translates to:
  /// **'Hot'**
  String get leaderboardSortHot;

  /// No description provided for @leaderboardSortVotes.
  ///
  /// In en, this message translates to:
  /// **'Votes'**
  String get leaderboardSortVotes;

  /// No description provided for @leaderboardAddItem.
  ///
  /// In en, this message translates to:
  /// **'Add item'**
  String get leaderboardAddItem;

  /// No description provided for @leaderboardVoteCount.
  ///
  /// In en, this message translates to:
  /// **'Votes'**
  String get leaderboardVoteCount;

  /// No description provided for @paymentSetupAccount.
  ///
  /// In en, this message translates to:
  /// **'Setup Payment Account'**
  String get paymentSetupAccount;

  /// No description provided for @paymentPleaseSetupFirst.
  ///
  /// In en, this message translates to:
  /// **'Please set up payment account first'**
  String get paymentPleaseSetupFirst;

  /// No description provided for @paymentPleaseSetupMessage.
  ///
  /// In en, this message translates to:
  /// **'You need to set up your payment account before applying for tasks. Please go to Settings to complete setup.'**
  String get paymentPleaseSetupMessage;

  /// No description provided for @notificationsNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsNotifications;

  /// No description provided for @notificationsNoNotifications.
  ///
  /// In en, this message translates to:
  /// **'No notifications'**
  String get notificationsNoNotifications;

  /// No description provided for @notificationsMarkAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark All as Read'**
  String get notificationsMarkAllRead;

  /// No description provided for @notificationAgree.
  ///
  /// In en, this message translates to:
  /// **'Agree'**
  String get notificationAgree;

  /// No description provided for @notificationReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get notificationReject;

  /// No description provided for @notificationExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get notificationExpired;

  /// No description provided for @notificationNoNotifications.
  ///
  /// In en, this message translates to:
  /// **'No Notifications'**
  String get notificationNoNotifications;

  /// No description provided for @notificationNoNotificationsMessage.
  ///
  /// In en, this message translates to:
  /// **'No notification messages received yet'**
  String get notificationNoNotificationsMessage;

  /// No description provided for @notificationEnableNotification.
  ///
  /// In en, this message translates to:
  /// **'Enable Notifications'**
  String get notificationEnableNotification;

  /// No description provided for @notificationEnableNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Enable Notifications'**
  String get notificationEnableNotificationTitle;

  /// No description provided for @notificationEnableNotificationMessage.
  ///
  /// In en, this message translates to:
  /// **'Receive task updates and message reminders in time'**
  String get notificationEnableNotificationMessage;

  /// No description provided for @notificationEnableNotificationDescription.
  ///
  /// In en, this message translates to:
  /// **'Don\'t miss any important information'**
  String get notificationEnableNotificationDescription;

  /// No description provided for @notificationAllowNotification.
  ///
  /// In en, this message translates to:
  /// **'Allow Notifications'**
  String get notificationAllowNotification;

  /// No description provided for @notificationNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not Now'**
  String get notificationNotNow;

  /// No description provided for @studentVerificationVerification.
  ///
  /// In en, this message translates to:
  /// **'Student Verification'**
  String get studentVerificationVerification;

  /// No description provided for @studentVerificationSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit Verification'**
  String get studentVerificationSubmit;

  /// No description provided for @studentVerificationUploadDocument.
  ///
  /// In en, this message translates to:
  /// **'Upload Document'**
  String get studentVerificationUploadDocument;

  /// No description provided for @studentVerificationEmailInfo.
  ///
  /// In en, this message translates to:
  /// **'Email Information'**
  String get studentVerificationEmailInfo;

  /// No description provided for @studentVerificationSchoolEmail.
  ///
  /// In en, this message translates to:
  /// **'School Email'**
  String get studentVerificationSchoolEmail;

  /// No description provided for @studentVerificationSchoolEmailPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Enter your .ac.uk or .edu email'**
  String get studentVerificationSchoolEmailPlaceholder;

  /// No description provided for @studentVerificationRenewVerification.
  ///
  /// In en, this message translates to:
  /// **'Renew Verification'**
  String get studentVerificationRenewVerification;

  /// No description provided for @studentVerificationChangeEmail.
  ///
  /// In en, this message translates to:
  /// **'Change Email'**
  String get studentVerificationChangeEmail;

  /// No description provided for @studentVerificationSubmitVerification.
  ///
  /// In en, this message translates to:
  /// **'Submit Verification'**
  String get studentVerificationSubmitVerification;

  /// No description provided for @studentVerificationStudentVerificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Student Verification'**
  String get studentVerificationStudentVerificationTitle;

  /// No description provided for @studentVerificationDescription.
  ///
  /// In en, this message translates to:
  /// **'Verify your student identity to enjoy student-exclusive benefits'**
  String get studentVerificationDescription;

  /// No description provided for @studentVerificationStartVerification.
  ///
  /// In en, this message translates to:
  /// **'Start Verification'**
  String get studentVerificationStartVerification;

  /// No description provided for @studentVerificationStatus.
  ///
  /// In en, this message translates to:
  /// **'Status: {param1}'**
  String studentVerificationStatus(String param1);

  /// No description provided for @studentVerificationEmailInstruction.
  ///
  /// In en, this message translates to:
  /// **'Note: Please enter your school email address, and we will send a verification email to that address.'**
  String get studentVerificationEmailInstruction;

  /// No description provided for @studentVerificationRenewInfo.
  ///
  /// In en, this message translates to:
  /// **'Renewal Information'**
  String get studentVerificationRenewInfo;

  /// No description provided for @studentVerificationRenewEmailPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Enter your school email'**
  String get studentVerificationRenewEmailPlaceholder;

  /// No description provided for @studentVerificationRenewInstruction.
  ///
  /// In en, this message translates to:
  /// **'Note: Please enter your school email address to renew verification.'**
  String get studentVerificationRenewInstruction;

  /// No description provided for @studentVerificationNewSchoolEmail.
  ///
  /// In en, this message translates to:
  /// **'New School Email'**
  String get studentVerificationNewSchoolEmail;

  /// No description provided for @studentVerificationNewSchoolEmailPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Enter new school email'**
  String get studentVerificationNewSchoolEmailPlaceholder;

  /// No description provided for @studentVerificationChangeEmailInstruction.
  ///
  /// In en, this message translates to:
  /// **'Note: Please enter a new school email address. After changing, re-verification is required.'**
  String get studentVerificationChangeEmailInstruction;

  /// No description provided for @studentVerificationBenefitCampusLife.
  ///
  /// In en, this message translates to:
  /// **'Post Campus Life Tasks'**
  String get studentVerificationBenefitCampusLife;

  /// No description provided for @studentVerificationBenefitCampusLifeDescription.
  ///
  /// In en, this message translates to:
  /// **'Post and participate in campus life related tasks'**
  String get studentVerificationBenefitCampusLifeDescription;

  /// No description provided for @studentVerificationBenefitStudentCommunity.
  ///
  /// In en, this message translates to:
  /// **'Access Student Community'**
  String get studentVerificationBenefitStudentCommunity;

  /// No description provided for @studentVerificationBenefitStudentCommunityDescription.
  ///
  /// In en, this message translates to:
  /// **'Access exclusive student forum sections and interact with schoolmates'**
  String get studentVerificationBenefitStudentCommunityDescription;

  /// No description provided for @studentVerificationBenefitExclusiveBenefits.
  ///
  /// In en, this message translates to:
  /// **'Student-Exclusive Benefits'**
  String get studentVerificationBenefitExclusiveBenefits;

  /// No description provided for @studentVerificationBenefitExclusiveBenefitsDescription.
  ///
  /// In en, this message translates to:
  /// **'Enjoy student discounts, exclusive events and more privileges'**
  String get studentVerificationBenefitExclusiveBenefitsDescription;

  /// No description provided for @studentVerificationBenefitVerificationBadge.
  ///
  /// In en, this message translates to:
  /// **'Verification Badge'**
  String get studentVerificationBenefitVerificationBadge;

  /// No description provided for @studentVerificationBenefitVerificationBadgeDescription.
  ///
  /// In en, this message translates to:
  /// **'Display student verification badge on profile to increase trust'**
  String get studentVerificationBenefitVerificationBadgeDescription;

  /// No description provided for @studentVerificationVerificationEmail.
  ///
  /// In en, this message translates to:
  /// **'Verification Email'**
  String get studentVerificationVerificationEmail;

  /// No description provided for @studentVerificationVerificationTime.
  ///
  /// In en, this message translates to:
  /// **'Verification Time'**
  String get studentVerificationVerificationTime;

  /// No description provided for @studentVerificationExpiryTime.
  ///
  /// In en, this message translates to:
  /// **'Expiry Time'**
  String get studentVerificationExpiryTime;

  /// No description provided for @studentVerificationDaysRemaining.
  ///
  /// In en, this message translates to:
  /// **'Days Remaining'**
  String get studentVerificationDaysRemaining;

  /// No description provided for @studentVerificationDaysFormat.
  ///
  /// In en, this message translates to:
  /// **'{param1} days'**
  String studentVerificationDaysFormat(int param1);

  /// No description provided for @studentVerificationSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Submitting...'**
  String get studentVerificationSubmitting;

  /// No description provided for @studentVerificationSendEmail.
  ///
  /// In en, this message translates to:
  /// **'Send Verification Email'**
  String get studentVerificationSendEmail;

  /// No description provided for @studentVerificationRenewing.
  ///
  /// In en, this message translates to:
  /// **'Renewing...'**
  String get studentVerificationRenewing;

  /// No description provided for @studentVerificationRenewNow.
  ///
  /// In en, this message translates to:
  /// **'Renew Now'**
  String get studentVerificationRenewNow;

  /// No description provided for @studentVerificationChanging.
  ///
  /// In en, this message translates to:
  /// **'Changing...'**
  String get studentVerificationChanging;

  /// No description provided for @studentVerificationConfirmChange.
  ///
  /// In en, this message translates to:
  /// **'Confirm Change'**
  String get studentVerificationConfirmChange;

  /// No description provided for @studentVerificationVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get studentVerificationVerified;

  /// No description provided for @studentVerificationUnverified.
  ///
  /// In en, this message translates to:
  /// **'Unverified'**
  String get studentVerificationUnverified;

  /// No description provided for @studentVerificationStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get studentVerificationStatusPending;

  /// No description provided for @studentVerificationStatusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get studentVerificationStatusExpired;

  /// No description provided for @studentVerificationStatusRevoked.
  ///
  /// In en, this message translates to:
  /// **'Revoked'**
  String get studentVerificationStatusRevoked;

  /// No description provided for @studentVerificationBenefitsTitleVerified.
  ///
  /// In en, this message translates to:
  /// **'Student Benefits You Enjoy'**
  String get studentVerificationBenefitsTitleVerified;

  /// No description provided for @studentVerificationBenefitsTitleUnverified.
  ///
  /// In en, this message translates to:
  /// **'After verification, you will get'**
  String get studentVerificationBenefitsTitleUnverified;

  /// No description provided for @customerServiceCustomerService.
  ///
  /// In en, this message translates to:
  /// **'Customer Service'**
  String get customerServiceCustomerService;

  /// No description provided for @customerServiceChatWithService.
  ///
  /// In en, this message translates to:
  /// **'Chat with Customer Service'**
  String get customerServiceChatWithService;

  /// No description provided for @activityActivity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get activityActivity;

  /// No description provided for @activityRecentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent Activity'**
  String get activityRecentActivity;

  /// No description provided for @activityPostedForumPost.
  ///
  /// In en, this message translates to:
  /// **'posted a forum post'**
  String get activityPostedForumPost;

  /// No description provided for @activityPostedFleaMarketItem.
  ///
  /// In en, this message translates to:
  /// **'posted a flea market item'**
  String get activityPostedFleaMarketItem;

  /// No description provided for @activityCreatedLeaderboard.
  ///
  /// In en, this message translates to:
  /// **'created a leaderboard'**
  String get activityCreatedLeaderboard;

  /// No description provided for @activityEnded.
  ///
  /// In en, this message translates to:
  /// **'Ended'**
  String get activityEnded;

  /// No description provided for @activityFull.
  ///
  /// In en, this message translates to:
  /// **'Full'**
  String get activityFull;

  /// No description provided for @activityApply.
  ///
  /// In en, this message translates to:
  /// **'Apply to Join'**
  String get activityApply;

  /// No description provided for @activityApplied.
  ///
  /// In en, this message translates to:
  /// **'Applied'**
  String get activityApplied;

  /// No description provided for @activityParticipated.
  ///
  /// In en, this message translates to:
  /// **'Participated'**
  String get activityParticipated;

  /// No description provided for @activityApplyToJoin.
  ///
  /// In en, this message translates to:
  /// **'Apply to Join Activity'**
  String get activityApplyToJoin;

  /// No description provided for @searchSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchSearch;

  /// No description provided for @searchResults.
  ///
  /// In en, this message translates to:
  /// **'Results'**
  String get searchResults;

  /// No description provided for @searchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get searchNoResults;

  /// No description provided for @searchTryOtherKeywords.
  ///
  /// In en, this message translates to:
  /// **'Try other keywords'**
  String get searchTryOtherKeywords;

  /// No description provided for @searchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search tasks, experts, items...'**
  String get searchPlaceholder;

  /// No description provided for @searchTaskPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search tasks'**
  String get searchTaskPlaceholder;

  /// No description provided for @errorNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Network Error'**
  String get errorNetworkError;

  /// No description provided for @errorUnknownError.
  ///
  /// In en, this message translates to:
  /// **'Unknown Error'**
  String get errorUnknownError;

  /// No description provided for @errorInvalidInput.
  ///
  /// In en, this message translates to:
  /// **'Invalid Input'**
  String get errorInvalidInput;

  /// No description provided for @errorLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login Failed'**
  String get errorLoginFailed;

  /// No description provided for @errorRegisterFailed.
  ///
  /// In en, this message translates to:
  /// **'Registration Failed'**
  String get errorRegisterFailed;

  /// No description provided for @errorError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get errorError;

  /// No description provided for @errorRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get errorRetry;

  /// No description provided for @errorSomethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get errorSomethingWentWrong;

  /// No description provided for @errorInvalidUrl.
  ///
  /// In en, this message translates to:
  /// **'Invalid request URL, please try again later'**
  String get errorInvalidUrl;

  /// No description provided for @errorNetworkConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Network connection failed, please check your network settings'**
  String get errorNetworkConnectionFailed;

  /// No description provided for @errorRequestTimeout.
  ///
  /// In en, this message translates to:
  /// **'Request timeout, please try again later'**
  String get errorRequestTimeout;

  /// No description provided for @errorNetworkRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'Network request failed, please try again later'**
  String get errorNetworkRequestFailed;

  /// No description provided for @errorInvalidResponse.
  ///
  /// In en, this message translates to:
  /// **'Server response error, please try again later'**
  String get errorInvalidResponse;

  /// No description provided for @errorBadRequest.
  ///
  /// In en, this message translates to:
  /// **'Invalid request parameters'**
  String get errorBadRequest;

  /// No description provided for @errorUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Login expired, please login again'**
  String get errorUnauthorized;

  /// No description provided for @errorForbidden.
  ///
  /// In en, this message translates to:
  /// **'No permission to perform this operation'**
  String get errorForbidden;

  /// No description provided for @errorNotFound.
  ///
  /// In en, this message translates to:
  /// **'Requested resource does not exist'**
  String get errorNotFound;

  /// No description provided for @errorTooManyRequests.
  ///
  /// In en, this message translates to:
  /// **'Too many requests, please try again later'**
  String get errorTooManyRequests;

  /// No description provided for @errorServerError.
  ///
  /// In en, this message translates to:
  /// **'Server error, please try again later'**
  String get errorServerError;

  /// No description provided for @errorRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'Request failed (Error code: {param1})'**
  String errorRequestFailed(int param1);

  /// No description provided for @errorDecodingError.
  ///
  /// In en, this message translates to:
  /// **'Data parsing failed, please try again later'**
  String get errorDecodingError;

  /// No description provided for @errorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown error occurred, please try again later'**
  String get errorUnknown;

  /// No description provided for @errorFileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'File too large'**
  String get errorFileTooLarge;

  /// No description provided for @errorFileTooLargeWithDetail.
  ///
  /// In en, this message translates to:
  /// **'File too large: {param1}'**
  String errorFileTooLargeWithDetail(String param1);

  /// No description provided for @errorRequestFailedWithReason.
  ///
  /// In en, this message translates to:
  /// **'Request failed: {param1}'**
  String errorRequestFailedWithReason(String param1);

  /// No description provided for @errorInvalidResponseBody.
  ///
  /// In en, this message translates to:
  /// **'Invalid response'**
  String get errorInvalidResponseBody;

  /// No description provided for @errorServerErrorCode.
  ///
  /// In en, this message translates to:
  /// **'Server error (code: {param1})'**
  String errorServerErrorCode(int param1);

  /// No description provided for @errorServerErrorCodeWithMessage.
  ///
  /// In en, this message translates to:
  /// **'Server error (code: {param2}): {param1}'**
  String errorServerErrorCodeWithMessage(String param1, int param2);

  /// No description provided for @errorDecodingErrorWithReason.
  ///
  /// In en, this message translates to:
  /// **'Data parsing error: {param1}'**
  String errorDecodingErrorWithReason(String param1);

  /// No description provided for @errorCodeEmailAlreadyUsed.
  ///
  /// In en, this message translates to:
  /// **'This email is already used by another account'**
  String get errorCodeEmailAlreadyUsed;

  /// No description provided for @errorCodeEmailAlreadyExists.
  ///
  /// In en, this message translates to:
  /// **'This email is already registered. Use another email or log in'**
  String get errorCodeEmailAlreadyExists;

  /// No description provided for @errorCodePhoneAlreadyUsed.
  ///
  /// In en, this message translates to:
  /// **'This phone number is already used by another account'**
  String get errorCodePhoneAlreadyUsed;

  /// No description provided for @errorCodePhoneAlreadyExists.
  ///
  /// In en, this message translates to:
  /// **'This phone number is already registered. Use another or log in'**
  String get errorCodePhoneAlreadyExists;

  /// No description provided for @errorCodeUsernameAlreadyExists.
  ///
  /// In en, this message translates to:
  /// **'This username is already taken. Please choose another'**
  String get errorCodeUsernameAlreadyExists;

  /// No description provided for @errorCodeCodeInvalidOrExpired.
  ///
  /// In en, this message translates to:
  /// **'Verification code is invalid or expired. Please request a new one'**
  String get errorCodeCodeInvalidOrExpired;

  /// No description provided for @errorCodeSendCodeFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send verification code. Please try again later'**
  String get errorCodeSendCodeFailed;

  /// No description provided for @errorCodeEmailUpdateNeedCode.
  ///
  /// In en, this message translates to:
  /// **'Please send a verification code to your new email first'**
  String get errorCodeEmailUpdateNeedCode;

  /// No description provided for @errorCodePhoneUpdateNeedCode.
  ///
  /// In en, this message translates to:
  /// **'Please send a verification code to your new phone number first'**
  String get errorCodePhoneUpdateNeedCode;

  /// No description provided for @errorCodeTempEmailNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'Temporary email addresses are not allowed. Please use a real email'**
  String get errorCodeTempEmailNotAllowed;

  /// No description provided for @errorCodeLoginRequired.
  ///
  /// In en, this message translates to:
  /// **'Please log in to view'**
  String get errorCodeLoginRequired;

  /// No description provided for @errorCodeForbiddenView.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have permission to view this'**
  String get errorCodeForbiddenView;

  /// No description provided for @errorCodeTaskAlreadyApplied.
  ///
  /// In en, this message translates to:
  /// **'You have already applied for this task'**
  String get errorCodeTaskAlreadyApplied;

  /// No description provided for @errorCodeDisputeAlreadySubmitted.
  ///
  /// In en, this message translates to:
  /// **'You have already submitted a dispute. Please wait for review'**
  String get errorCodeDisputeAlreadySubmitted;

  /// No description provided for @errorCodeRebuttalAlreadySubmitted.
  ///
  /// In en, this message translates to:
  /// **'You have already submitted a rebuttal'**
  String get errorCodeRebuttalAlreadySubmitted;

  /// No description provided for @errorCodeTaskNotPaid.
  ///
  /// In en, this message translates to:
  /// **'Task is not paid yet. Please complete payment first'**
  String get errorCodeTaskNotPaid;

  /// No description provided for @errorCodeTaskPaymentUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Payment is no longer available for this task'**
  String get errorCodeTaskPaymentUnavailable;

  /// No description provided for @errorCodeStripeDisputeFrozen.
  ///
  /// In en, this message translates to:
  /// **'This task is frozen due to a Stripe dispute. Please wait for it to be resolved'**
  String get errorCodeStripeDisputeFrozen;

  /// No description provided for @errorCodeStripeSetupRequired.
  ///
  /// In en, this message translates to:
  /// **'Please complete payout account setup first'**
  String get errorCodeStripeSetupRequired;

  /// No description provided for @errorCodeStripeOtherPartyNotSetup.
  ///
  /// In en, this message translates to:
  /// **'The other party has not set up their payout account. Please ask them to complete setup'**
  String get errorCodeStripeOtherPartyNotSetup;

  /// No description provided for @errorCodeStripeAccountNotVerified.
  ///
  /// In en, this message translates to:
  /// **'Payout account is not verified yet. Please complete account verification'**
  String get errorCodeStripeAccountNotVerified;

  /// No description provided for @errorCodeStripeAccountInvalid.
  ///
  /// In en, this message translates to:
  /// **'Payout account is invalid. Please set it up again'**
  String get errorCodeStripeAccountInvalid;

  /// No description provided for @errorCodeStripeVerificationFailed.
  ///
  /// In en, this message translates to:
  /// **'Payout account verification failed. Please check your network and try again'**
  String get errorCodeStripeVerificationFailed;

  /// No description provided for @errorCodeRefundAmountRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter refund amount or percentage'**
  String get errorCodeRefundAmountRequired;

  /// No description provided for @errorCodeEvidenceFilesLimit.
  ///
  /// In en, this message translates to:
  /// **'Too many evidence files'**
  String get errorCodeEvidenceFilesLimit;

  /// No description provided for @errorCodeEvidenceTextLimit.
  ///
  /// In en, this message translates to:
  /// **'Evidence text must be 500 characters or less'**
  String get errorCodeEvidenceTextLimit;

  /// No description provided for @errorCodeAccountHasActiveTasks.
  ///
  /// In en, this message translates to:
  /// **'Cannot delete account: you have active tasks. Complete or cancel them first'**
  String get errorCodeAccountHasActiveTasks;

  /// No description provided for @errorCodeTempEmailNoPasswordReset.
  ///
  /// In en, this message translates to:
  /// **'Temporary email cannot receive password reset. Please update your email in Settings'**
  String get errorCodeTempEmailNoPasswordReset;

  /// No description provided for @stripeDashboard.
  ///
  /// In en, this message translates to:
  /// **'Stripe Dashboard'**
  String get stripeDashboard;

  /// No description provided for @stripeConnectInitFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to initialise payout account setup'**
  String get stripeConnectInitFailed;

  /// No description provided for @stripeConnectLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Payout setup failed to load, please try again'**
  String get stripeConnectLoadFailed;

  /// No description provided for @stripeConnectOnboardingCancelled.
  ///
  /// In en, this message translates to:
  /// **'Payment account setup was cancelled'**
  String get stripeConnectOnboardingCancelled;

  /// No description provided for @stripeConnectOnboardingFailed.
  ///
  /// In en, this message translates to:
  /// **'Payment account setup failed'**
  String get stripeConnectOnboardingFailed;

  /// No description provided for @stripeConnectOnboardingErrorHint.
  ///
  /// In en, this message translates to:
  /// **'If you see \"Sorry, something went wrong\" in the page, check your network or try again later; ensure the app and backend use the same Stripe environment (test/live).'**
  String get stripeConnectOnboardingErrorHint;

  /// No description provided for @stripeConnectLoadFailedWithReason.
  ///
  /// In en, this message translates to:
  /// **'Load failed: {param1}'**
  String stripeConnectLoadFailedWithReason(String param1);

  /// No description provided for @stripeConnectOpenDashboard.
  ///
  /// In en, this message translates to:
  /// **'Open Stripe Dashboard'**
  String get stripeConnectOpenDashboard;

  /// No description provided for @stripeConnectDashboardUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unable to open Stripe dashboard'**
  String get stripeConnectDashboardUnavailable;

  /// No description provided for @stripeOnboardingCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to create payout setup session, please try again'**
  String get stripeOnboardingCreateFailed;

  /// No description provided for @uploadNetworkErrorWithReason.
  ///
  /// In en, this message translates to:
  /// **'Network error: {param1}'**
  String uploadNetworkErrorWithReason(String param1);

  /// No description provided for @uploadCannotConnectServer.
  ///
  /// In en, this message translates to:
  /// **'Cannot connect to server, please try again later'**
  String get uploadCannotConnectServer;

  /// No description provided for @uploadBadRequestFormatImage.
  ///
  /// In en, this message translates to:
  /// **'Invalid request format, please check image format'**
  String get uploadBadRequestFormatImage;

  /// No description provided for @uploadBadRequestRetry.
  ///
  /// In en, this message translates to:
  /// **'Invalid request, please try again'**
  String get uploadBadRequestRetry;

  /// No description provided for @uploadFileTooLargeChooseSmaller.
  ///
  /// In en, this message translates to:
  /// **'File too large, please choose a smaller file'**
  String get uploadFileTooLargeChooseSmaller;

  /// No description provided for @uploadForbiddenUploadImage.
  ///
  /// In en, this message translates to:
  /// **'No permission to upload image'**
  String get uploadForbiddenUploadImage;

  /// No description provided for @uploadForbiddenUploadFile.
  ///
  /// In en, this message translates to:
  /// **'No permission to upload file'**
  String get uploadForbiddenUploadFile;

  /// No description provided for @uploadImageTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Image too large, please choose a smaller one'**
  String get uploadImageTooLarge;

  /// No description provided for @uploadImageTooLargeWithMessage.
  ///
  /// In en, this message translates to:
  /// **'Image too large: {param1}'**
  String uploadImageTooLargeWithMessage(String param1);

  /// No description provided for @uploadServerErrorRetry.
  ///
  /// In en, this message translates to:
  /// **'Server error ({param1}), please try again later'**
  String uploadServerErrorRetry(int param1);

  /// No description provided for @uploadServerErrorCode.
  ///
  /// In en, this message translates to:
  /// **'Server error ({param1})'**
  String uploadServerErrorCode(int param1);

  /// No description provided for @uploadBadRequestWithMessage.
  ///
  /// In en, this message translates to:
  /// **'Invalid request: {param1}'**
  String uploadBadRequestWithMessage(String param1);

  /// No description provided for @uploadServerErrorCodeWithMessage.
  ///
  /// In en, this message translates to:
  /// **'Server error ({param2}): {param1}'**
  String uploadServerErrorCodeWithMessage(String param1, int param2);

  /// No description provided for @uploadParseResponseFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to parse response: {param1}'**
  String uploadParseResponseFailed(String param1);

  /// No description provided for @uploadInvalidResponseFormat.
  ///
  /// In en, this message translates to:
  /// **'Invalid server response format'**
  String get uploadInvalidResponseFormat;

  /// No description provided for @uploadUnknownRetry.
  ///
  /// In en, this message translates to:
  /// **'Unknown error, please try again'**
  String get uploadUnknownRetry;

  /// No description provided for @uploadAllFailed.
  ///
  /// In en, this message translates to:
  /// **'All image uploads failed.\\n{param1}'**
  String uploadAllFailed(String param1);

  /// No description provided for @uploadPartialFailed.
  ///
  /// In en, this message translates to:
  /// **'Some image uploads failed:\\n{param1}'**
  String uploadPartialFailed(String param1);

  /// No description provided for @uploadPartialFailedContinue.
  ///
  /// In en, this message translates to:
  /// **'Some image uploads failed, continuing with uploaded images:\\n{param1}'**
  String uploadPartialFailedContinue(String param1);

  /// No description provided for @uploadImageIndexError.
  ///
  /// In en, this message translates to:
  /// **'Image {param2}: {param1}'**
  String uploadImageIndexError(String param1, int param2);

  /// No description provided for @refundForbidden.
  ///
  /// In en, this message translates to:
  /// **'No permission to submit refund request'**
  String get refundForbidden;

  /// No description provided for @refundTaskNotFound.
  ///
  /// In en, this message translates to:
  /// **'Task not found or no access'**
  String get refundTaskNotFound;

  /// No description provided for @refundBadRequestFormat.
  ///
  /// In en, this message translates to:
  /// **'Invalid request, please check your input'**
  String get refundBadRequestFormat;

  /// No description provided for @successOperationSuccess.
  ///
  /// In en, this message translates to:
  /// **'Operation Successful'**
  String get successOperationSuccess;

  /// No description provided for @successSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get successSaved;

  /// No description provided for @successDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get successDeleted;

  /// No description provided for @successRefreshSuccess.
  ///
  /// In en, this message translates to:
  /// **'Refresh successful'**
  String get successRefreshSuccess;

  /// No description provided for @successRefreshSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Item refreshed, auto-removal timer reset'**
  String get successRefreshSuccessMessage;

  /// No description provided for @currencyPound.
  ///
  /// In en, this message translates to:
  /// **'£'**
  String get currencyPound;

  /// No description provided for @currencyPoints.
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get currencyPoints;

  /// No description provided for @pointsBalance.
  ///
  /// In en, this message translates to:
  /// **'Points Balance'**
  String get pointsBalance;

  /// No description provided for @pointsUnit.
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get pointsUnit;

  /// No description provided for @pointsTotalEarned.
  ///
  /// In en, this message translates to:
  /// **'Total Earned'**
  String get pointsTotalEarned;

  /// No description provided for @pointsTotalSpent.
  ///
  /// In en, this message translates to:
  /// **'Total Spent'**
  String get pointsTotalSpent;

  /// No description provided for @pointsBalanceAfter.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get pointsBalanceAfter;

  /// No description provided for @pointsAmountFormat.
  ///
  /// In en, this message translates to:
  /// **'{param1} Points'**
  String pointsAmountFormat(int param1);

  /// No description provided for @pointsBalanceFormat.
  ///
  /// In en, this message translates to:
  /// **'Balance: {param1} Points'**
  String pointsBalanceFormat(int param1);

  /// No description provided for @pointsPoints.
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get pointsPoints;

  /// No description provided for @pointsPointsAndPayment.
  ///
  /// In en, this message translates to:
  /// **'Points + Payment'**
  String get pointsPointsAndPayment;

  /// No description provided for @pointsPointsDeduction.
  ///
  /// In en, this message translates to:
  /// **'Points Deduction'**
  String get pointsPointsDeduction;

  /// No description provided for @pointsCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Check In'**
  String get pointsCheckIn;

  /// No description provided for @pointsCheckedInToday.
  ///
  /// In en, this message translates to:
  /// **'Checked In Today'**
  String get pointsCheckedInToday;

  /// No description provided for @pointsCheckInReward.
  ///
  /// In en, this message translates to:
  /// **'Check In for Points'**
  String get pointsCheckInReward;

  /// No description provided for @pointsCheckInDescription.
  ///
  /// In en, this message translates to:
  /// **'• Daily check-in rewards points\\n• More consecutive days, more rewards\\n• Consecutive days reset after interruption'**
  String get pointsCheckInDescription;

  /// No description provided for @pointsTransactionHistory.
  ///
  /// In en, this message translates to:
  /// **'Your point transaction history will be displayed here'**
  String get pointsTransactionHistory;

  /// No description provided for @pointsNoTransactionHistory.
  ///
  /// In en, this message translates to:
  /// **'No transaction history'**
  String get pointsNoTransactionHistory;

  /// No description provided for @pointsPointsAndCoupons.
  ///
  /// In en, this message translates to:
  /// **'Points & Coupons'**
  String get pointsPointsAndCoupons;

  /// No description provided for @pointsShowRecentOnly.
  ///
  /// In en, this message translates to:
  /// **'Show recent records only'**
  String get pointsShowRecentOnly;

  /// No description provided for @couponCoupons.
  ///
  /// In en, this message translates to:
  /// **'Coupons'**
  String get couponCoupons;

  /// No description provided for @couponCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Check In'**
  String get couponCheckIn;

  /// No description provided for @couponAllowed.
  ///
  /// In en, this message translates to:
  /// **'Allowed'**
  String get couponAllowed;

  /// No description provided for @couponForbidden.
  ///
  /// In en, this message translates to:
  /// **'Forbidden'**
  String get couponForbidden;

  /// No description provided for @couponCheckInRules.
  ///
  /// In en, this message translates to:
  /// **'Check-in Rules'**
  String get couponCheckInRules;

  /// No description provided for @couponStatusUnused.
  ///
  /// In en, this message translates to:
  /// **'Unused'**
  String get couponStatusUnused;

  /// No description provided for @couponStatusUsed.
  ///
  /// In en, this message translates to:
  /// **'Used'**
  String get couponStatusUsed;

  /// No description provided for @couponStatusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get couponStatusExpired;

  /// No description provided for @couponTypeFixedAmount.
  ///
  /// In en, this message translates to:
  /// **'Fixed Discount'**
  String get couponTypeFixedAmount;

  /// No description provided for @couponTypePercentage.
  ///
  /// In en, this message translates to:
  /// **'Percentage Off'**
  String get couponTypePercentage;

  /// No description provided for @pointsTypeEarn.
  ///
  /// In en, this message translates to:
  /// **'Points Earned'**
  String get pointsTypeEarn;

  /// No description provided for @pointsTypeSpend.
  ///
  /// In en, this message translates to:
  /// **'Points Spent'**
  String get pointsTypeSpend;

  /// No description provided for @pointsTypeRefund.
  ///
  /// In en, this message translates to:
  /// **'Points Refunded'**
  String get pointsTypeRefund;

  /// No description provided for @pointsTypeExpire.
  ///
  /// In en, this message translates to:
  /// **'Points Expired'**
  String get pointsTypeExpire;

  /// No description provided for @pointsTypeCouponRedeem.
  ///
  /// In en, this message translates to:
  /// **'Coupon Redeemed'**
  String get pointsTypeCouponRedeem;

  /// No description provided for @timeJustNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get timeJustNow;

  /// No description provided for @timeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min ago'**
  String timeMinutesAgo(int minutes);

  /// No description provided for @timeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{hours} hr ago'**
  String timeHoursAgo(int hours);

  /// No description provided for @timeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{days}d ago'**
  String timeDaysAgo(int days);

  /// No description provided for @timeWeeksAgo.
  ///
  /// In en, this message translates to:
  /// **'{param1} weeks ago'**
  String timeWeeksAgo(int param1);

  /// No description provided for @timeMonthsAgo.
  ///
  /// In en, this message translates to:
  /// **'{param1} months ago'**
  String timeMonthsAgo(int param1);

  /// No description provided for @timeYearsAgo.
  ///
  /// In en, this message translates to:
  /// **'{param1} years ago'**
  String timeYearsAgo(int param1);

  /// No description provided for @timeSecondsAgo.
  ///
  /// In en, this message translates to:
  /// **'{param1} seconds ago'**
  String timeSecondsAgo(int param1);

  /// No description provided for @timeDeadlineUnknown.
  ///
  /// In en, this message translates to:
  /// **'Deadline unknown'**
  String get timeDeadlineUnknown;

  /// No description provided for @timeExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get timeExpired;

  /// No description provided for @timeMonths.
  ///
  /// In en, this message translates to:
  /// **'{param1} months'**
  String timeMonths(int param1);

  /// No description provided for @timeWeeks.
  ///
  /// In en, this message translates to:
  /// **'{param1} weeks'**
  String timeWeeks(int param1);

  /// No description provided for @timeDays.
  ///
  /// In en, this message translates to:
  /// **'{param1} days'**
  String timeDays(int param1);

  /// No description provided for @timeHours.
  ///
  /// In en, this message translates to:
  /// **'{param1} hours'**
  String timeHours(int param1);

  /// No description provided for @timeMinutes.
  ///
  /// In en, this message translates to:
  /// **'{param1} minutes'**
  String timeMinutes(int param1);

  /// No description provided for @timeSeconds.
  ///
  /// In en, this message translates to:
  /// **'{param1} seconds'**
  String timeSeconds(int param1);

  /// No description provided for @timeMonthDayFormat.
  ///
  /// In en, this message translates to:
  /// **'MMM d'**
  String get timeMonthDayFormat;

  /// No description provided for @timeYearMonthDayFormat.
  ///
  /// In en, this message translates to:
  /// **'MMM d, yyyy'**
  String get timeYearMonthDayFormat;

  /// No description provided for @timeDurationHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{param1} hours {param2} minutes'**
  String timeDurationHoursMinutes(int param1, int param2);

  /// No description provided for @timeDurationMinutesSeconds.
  ///
  /// In en, this message translates to:
  /// **'{param1} minutes {param2} seconds'**
  String timeDurationMinutesSeconds(int param1, int param2);

  /// No description provided for @timeDurationSeconds.
  ///
  /// In en, this message translates to:
  /// **'{param1} seconds'**
  String timeDurationSeconds(int param1);

  /// No description provided for @timeWan.
  ///
  /// In en, this message translates to:
  /// **'k'**
  String get timeWan;

  /// No description provided for @timeWanPlus.
  ///
  /// In en, this message translates to:
  /// **'+'**
  String get timeWanPlus;

  /// No description provided for @tabsHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get tabsHome;

  /// No description provided for @tabsCommunity.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get tabsCommunity;

  /// No description provided for @tabsCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get tabsCreate;

  /// No description provided for @tabsMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get tabsMessages;

  /// No description provided for @tabsProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get tabsProfile;

  /// No description provided for @communityForum.
  ///
  /// In en, this message translates to:
  /// **'Forum'**
  String get communityForum;

  /// No description provided for @communityLeaderboard.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get communityLeaderboard;

  /// No description provided for @communitySearchForumHint.
  ///
  /// In en, this message translates to:
  /// **'Search forums'**
  String get communitySearchForumHint;

  /// No description provided for @communitySearchLeaderboardHint.
  ///
  /// In en, this message translates to:
  /// **'Search leaderboards'**
  String get communitySearchLeaderboardHint;

  /// No description provided for @postPinned.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get postPinned;

  /// No description provided for @postFeatured.
  ///
  /// In en, this message translates to:
  /// **'Featured'**
  String get postFeatured;

  /// No description provided for @postOfficial.
  ///
  /// In en, this message translates to:
  /// **'Official'**
  String get postOfficial;

  /// No description provided for @postAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get postAll;

  /// No description provided for @actionsApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get actionsApprove;

  /// No description provided for @actionsReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get actionsReject;

  /// No description provided for @actionsChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get actionsChat;

  /// No description provided for @actionsShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get actionsShare;

  /// No description provided for @actionsCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionsCancel;

  /// No description provided for @actionsConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get actionsConfirm;

  /// No description provided for @actionsSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get actionsSubmit;

  /// No description provided for @actionsLoadingMessages.
  ///
  /// In en, this message translates to:
  /// **'Loading messages...'**
  String get actionsLoadingMessages;

  /// No description provided for @actionsNoMessagesYet.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get actionsNoMessagesYet;

  /// No description provided for @actionsStartConversation.
  ///
  /// In en, this message translates to:
  /// **'Start a conversation!'**
  String get actionsStartConversation;

  /// No description provided for @actionsEnterMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter message...'**
  String get actionsEnterMessage;

  /// No description provided for @actionsPrivateMessage.
  ///
  /// In en, this message translates to:
  /// **'Private Message'**
  String get actionsPrivateMessage;

  /// No description provided for @actionsProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing...'**
  String get actionsProcessing;

  /// No description provided for @actionsMarkComplete.
  ///
  /// In en, this message translates to:
  /// **'Mark Task Complete'**
  String get actionsMarkComplete;

  /// No description provided for @actionsConfirmComplete.
  ///
  /// In en, this message translates to:
  /// **'Confirm Task Complete'**
  String get actionsConfirmComplete;

  /// No description provided for @actionsContactRecipient.
  ///
  /// In en, this message translates to:
  /// **'Contact Recipient'**
  String get actionsContactRecipient;

  /// No description provided for @actionsContactPoster.
  ///
  /// In en, this message translates to:
  /// **'Contact Poster'**
  String get actionsContactPoster;

  /// No description provided for @actionsRateTask.
  ///
  /// In en, this message translates to:
  /// **'Rate Task'**
  String get actionsRateTask;

  /// No description provided for @actionsCancelTask.
  ///
  /// In en, this message translates to:
  /// **'Cancel Task'**
  String get actionsCancelTask;

  /// No description provided for @actionsApplyForTask.
  ///
  /// In en, this message translates to:
  /// **'Apply for Task'**
  String get actionsApplyForTask;

  /// No description provided for @actionsOptionalMessage.
  ///
  /// In en, this message translates to:
  /// **'Message (Optional)'**
  String get actionsOptionalMessage;

  /// No description provided for @actionsNegotiatePrice.
  ///
  /// In en, this message translates to:
  /// **'Negotiate Price'**
  String get actionsNegotiatePrice;

  /// No description provided for @actionsApplyReasonHint.
  ///
  /// In en, this message translates to:
  /// **'Explain your application reason to the publisher to improve success rate'**
  String get actionsApplyReasonHint;

  /// No description provided for @actionsSubmitApplication.
  ///
  /// In en, this message translates to:
  /// **'Submit Application'**
  String get actionsSubmitApplication;

  /// No description provided for @actionsCancelReason.
  ///
  /// In en, this message translates to:
  /// **'Cancel Reason (Optional)'**
  String get actionsCancelReason;

  /// No description provided for @actionsShareTo.
  ///
  /// In en, this message translates to:
  /// **'Share to...'**
  String get actionsShareTo;

  /// No description provided for @profileUser.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get profileUser;

  /// No description provided for @profileMyTasksSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View tasks I published and accepted'**
  String get profileMyTasksSubtitle;

  /// No description provided for @profileMyPostsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage my second-hand items'**
  String get profileMyPostsSubtitle;

  /// No description provided for @profileMyWallet.
  ///
  /// In en, this message translates to:
  /// **'My Wallet'**
  String get profileMyWallet;

  /// No description provided for @profileMyWalletSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View balance and transaction history'**
  String get profileMyWalletSubtitle;

  /// No description provided for @profileMyApplications.
  ///
  /// In en, this message translates to:
  /// **'My Activities'**
  String get profileMyApplications;

  /// No description provided for @profileMyApplicationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View applied and favorited activities'**
  String get profileMyApplicationsSubtitle;

  /// No description provided for @profilePointsCoupons.
  ///
  /// In en, this message translates to:
  /// **'Points & Coupons'**
  String get profilePointsCoupons;

  /// No description provided for @profilePointsCouponsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View points, coupons and check-in'**
  String get profilePointsCouponsSubtitle;

  /// No description provided for @profileStudentVerification.
  ///
  /// In en, this message translates to:
  /// **'Student Verification'**
  String get profileStudentVerification;

  /// No description provided for @profileStudentVerificationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Verify student identity for discounts'**
  String get profileStudentVerificationSubtitle;

  /// No description provided for @profileActivity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get profileActivity;

  /// No description provided for @profileActivitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'View and participate in activities'**
  String get profileActivitySubtitle;

  /// No description provided for @profileSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'App settings and preferences'**
  String get profileSettingsSubtitle;

  /// No description provided for @profileWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Link²Ur'**
  String get profileWelcome;

  /// No description provided for @profileLoginPrompt.
  ///
  /// In en, this message translates to:
  /// **'Login to access all features'**
  String get profileLoginPrompt;

  /// No description provided for @profileConfirmLogout.
  ///
  /// In en, this message translates to:
  /// **'Confirm Logout'**
  String get profileConfirmLogout;

  /// No description provided for @profileLogoutMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to logout?'**
  String get profileLogoutMessage;

  /// No description provided for @taskDetailTaskDetail.
  ///
  /// In en, this message translates to:
  /// **'Task Details'**
  String get taskDetailTaskDetail;

  /// No description provided for @taskDetailShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get taskDetailShare;

  /// No description provided for @taskDetailCancelTask.
  ///
  /// In en, this message translates to:
  /// **'Cancel Task'**
  String get taskDetailCancelTask;

  /// No description provided for @taskDetailCancelTaskConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to cancel this task?'**
  String get taskDetailCancelTaskConfirm;

  /// No description provided for @taskDetailNoTaskImages.
  ///
  /// In en, this message translates to:
  /// **'No task images'**
  String get taskDetailNoTaskImages;

  /// No description provided for @taskDetailVipTask.
  ///
  /// In en, this message translates to:
  /// **'VIP Task'**
  String get taskDetailVipTask;

  /// No description provided for @taskDetailSuperTask.
  ///
  /// In en, this message translates to:
  /// **'Super Task'**
  String get taskDetailSuperTask;

  /// No description provided for @taskDetailTaskDescription.
  ///
  /// In en, this message translates to:
  /// **'Task Description'**
  String get taskDetailTaskDescription;

  /// No description provided for @taskDetailTimeInfo.
  ///
  /// In en, this message translates to:
  /// **'Time Information'**
  String get taskDetailTimeInfo;

  /// No description provided for @taskDetailPublishTime.
  ///
  /// In en, this message translates to:
  /// **'Publish Time'**
  String get taskDetailPublishTime;

  /// No description provided for @taskDetailDeadline.
  ///
  /// In en, this message translates to:
  /// **'Deadline'**
  String get taskDetailDeadline;

  /// No description provided for @taskDetailPublisher.
  ///
  /// In en, this message translates to:
  /// **'Publisher'**
  String get taskDetailPublisher;

  /// No description provided for @taskDetailRecipient.
  ///
  /// In en, this message translates to:
  /// **'Recipient'**
  String get taskDetailRecipient;

  /// No description provided for @taskDetailBuyer.
  ///
  /// In en, this message translates to:
  /// **'Buyer'**
  String get taskDetailBuyer;

  /// No description provided for @taskDetailSeller.
  ///
  /// In en, this message translates to:
  /// **'Seller'**
  String get taskDetailSeller;

  /// No description provided for @taskDetailParticipant.
  ///
  /// In en, this message translates to:
  /// **'Participant'**
  String get taskDetailParticipant;

  /// No description provided for @taskDetailApplicant.
  ///
  /// In en, this message translates to:
  /// **'Applicant'**
  String get taskDetailApplicant;

  /// No description provided for @taskDetailEmailNotProvided.
  ///
  /// In en, this message translates to:
  /// **'Email not provided'**
  String get taskDetailEmailNotProvided;

  /// No description provided for @taskDetailYourTask.
  ///
  /// In en, this message translates to:
  /// **'This is your task'**
  String get taskDetailYourTask;

  /// No description provided for @taskDetailManageTask.
  ///
  /// In en, this message translates to:
  /// **'You can view applicants and manage the task below'**
  String get taskDetailManageTask;

  /// No description provided for @taskDetailReviews.
  ///
  /// In en, this message translates to:
  /// **'Reviews ({param1})'**
  String taskDetailReviews(int param1);

  /// No description provided for @taskDetailMyReviews.
  ///
  /// In en, this message translates to:
  /// **'My Reviews'**
  String get taskDetailMyReviews;

  /// No description provided for @taskDetailAnonymousUser.
  ///
  /// In en, this message translates to:
  /// **'Anonymous User'**
  String get taskDetailAnonymousUser;

  /// No description provided for @taskDetailUnknownUser.
  ///
  /// In en, this message translates to:
  /// **'Unknown User'**
  String get taskDetailUnknownUser;

  /// No description provided for @taskDetailApplyInfo.
  ///
  /// In en, this message translates to:
  /// **'Application Info'**
  String get taskDetailApplyInfo;

  /// No description provided for @taskDetailPriceNegotiation.
  ///
  /// In en, this message translates to:
  /// **'Price Negotiation'**
  String get taskDetailPriceNegotiation;

  /// No description provided for @taskDetailApplyReasonHint.
  ///
  /// In en, this message translates to:
  /// **'Explain your application reason to the publisher to improve success rate'**
  String get taskDetailApplyReasonHint;

  /// No description provided for @taskDetailSubmitApplication.
  ///
  /// In en, this message translates to:
  /// **'Submit Application'**
  String get taskDetailSubmitApplication;

  /// No description provided for @taskDetailApplicantsList.
  ///
  /// In en, this message translates to:
  /// **'Applicants List ({param1})'**
  String taskDetailApplicantsList(int param1);

  /// No description provided for @taskDetailNoApplicants.
  ///
  /// In en, this message translates to:
  /// **'No applicants'**
  String get taskDetailNoApplicants;

  /// No description provided for @taskDetailMessageLabel.
  ///
  /// In en, this message translates to:
  /// **'Message: {param1}'**
  String taskDetailMessageLabel(String param1);

  /// No description provided for @taskDetailWaitingReview.
  ///
  /// In en, this message translates to:
  /// **'Waiting for publisher review'**
  String get taskDetailWaitingReview;

  /// No description provided for @taskDetailTaskCompleted.
  ///
  /// In en, this message translates to:
  /// **'Task Completed'**
  String get taskDetailTaskCompleted;

  /// No description provided for @taskDetailApplicationApproved.
  ///
  /// In en, this message translates to:
  /// **'Application Approved'**
  String get taskDetailApplicationApproved;

  /// No description provided for @taskDetailApplicationRejected.
  ///
  /// In en, this message translates to:
  /// **'Application Rejected'**
  String get taskDetailApplicationRejected;

  /// No description provided for @taskDetailUnknownStatus.
  ///
  /// In en, this message translates to:
  /// **'Unknown Status'**
  String get taskDetailUnknownStatus;

  /// No description provided for @taskDetailApplicationSuccess.
  ///
  /// In en, this message translates to:
  /// **'Application Successful'**
  String get taskDetailApplicationSuccess;

  /// No description provided for @taskDetailApplicationSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'You have successfully applied for this task. Please wait for the publisher to review.'**
  String get taskDetailApplicationSuccessMessage;

  /// No description provided for @taskDetailTaskCompletedMessage.
  ///
  /// In en, this message translates to:
  /// **'Congratulations! You have completed the task. Please wait for the publisher to confirm.'**
  String get taskDetailTaskCompletedMessage;

  /// No description provided for @taskDetailConfirmCompletionSuccess.
  ///
  /// In en, this message translates to:
  /// **'Task Completion Confirmed'**
  String get taskDetailConfirmCompletionSuccess;

  /// No description provided for @taskDetailTaskAlreadyReviewed.
  ///
  /// In en, this message translates to:
  /// **'Task already reviewed'**
  String get taskDetailTaskAlreadyReviewed;

  /// No description provided for @taskDetailReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Rate Task'**
  String get taskDetailReviewTitle;

  /// No description provided for @taskDetailReviewCommentHint.
  ///
  /// In en, this message translates to:
  /// **'Share your experience (optional)'**
  String get taskDetailReviewCommentHint;

  /// No description provided for @taskDetailReviewAnonymous.
  ///
  /// In en, this message translates to:
  /// **'Anonymous review'**
  String get taskDetailReviewAnonymous;

  /// No description provided for @taskDetailReviewSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit review'**
  String get taskDetailReviewSubmit;

  /// No description provided for @taskDetailCompleteTaskSuccess.
  ///
  /// In en, this message translates to:
  /// **'Completion submitted'**
  String get taskDetailCompleteTaskSuccess;

  /// No description provided for @taskDetailConfirmCompletionSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Task status has been updated to completed. Rewards will be automatically transferred to the task recipient.'**
  String get taskDetailConfirmCompletionSuccessMessage;

  /// No description provided for @refundRequestSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Refund request submitted'**
  String get refundRequestSubmitted;

  /// No description provided for @refundRebuttalSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Rebuttal submitted'**
  String get refundRebuttalSubmitted;

  /// No description provided for @taskDetailApplicationApprovedMessage.
  ///
  /// In en, this message translates to:
  /// **'Congratulations! Your application has been approved. You can start working on the task.'**
  String get taskDetailApplicationApprovedMessage;

  /// No description provided for @taskDetailPendingPaymentMessage.
  ///
  /// In en, this message translates to:
  /// **'The task poster is paying the platform service fee. The task will start after payment is completed.'**
  String get taskDetailPendingPaymentMessage;

  /// No description provided for @taskDetailApplicationRejectedMessage.
  ///
  /// In en, this message translates to:
  /// **'Sorry, your application was not approved.'**
  String get taskDetailApplicationRejectedMessage;

  /// No description provided for @taskDetailAlreadyApplied.
  ///
  /// In en, this message translates to:
  /// **'You have already applied for this task.'**
  String get taskDetailAlreadyApplied;

  /// No description provided for @taskDetailTaskAcceptedByOthers.
  ///
  /// In en, this message translates to:
  /// **'This task has been accepted by another user.'**
  String get taskDetailTaskAcceptedByOthers;

  /// No description provided for @taskDetailPendingReview.
  ///
  /// In en, this message translates to:
  /// **'Pending Review'**
  String get taskDetailPendingReview;

  /// No description provided for @taskDetailApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get taskDetailApproved;

  /// No description provided for @taskDetailRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get taskDetailRejected;

  /// No description provided for @taskDetailRejectApplication.
  ///
  /// In en, this message translates to:
  /// **'Reject Application'**
  String get taskDetailRejectApplication;

  /// No description provided for @taskDetailRejectApplicationConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to reject this application? This action cannot be undone.'**
  String get taskDetailRejectApplicationConfirm;

  /// No description provided for @taskDetailUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get taskDetailUnknown;

  /// No description provided for @taskApplicationMessage.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get taskApplicationMessage;

  /// No description provided for @taskApplicationMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Write a message to the applicant...'**
  String get taskApplicationMessageHint;

  /// No description provided for @taskApplicationMessageSent.
  ///
  /// In en, this message translates to:
  /// **'Message sent'**
  String get taskApplicationMessageSent;

  /// No description provided for @taskApplicationMessageFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send message'**
  String get taskApplicationMessageFailed;

  /// No description provided for @taskDetailQualityGood.
  ///
  /// In en, this message translates to:
  /// **'Good Quality'**
  String get taskDetailQualityGood;

  /// No description provided for @taskDetailOnTime.
  ///
  /// In en, this message translates to:
  /// **'On Time'**
  String get taskDetailOnTime;

  /// No description provided for @taskDetailResponsible.
  ///
  /// In en, this message translates to:
  /// **'Responsible'**
  String get taskDetailResponsible;

  /// No description provided for @taskDetailGoodAttitude.
  ///
  /// In en, this message translates to:
  /// **'Good Attitude'**
  String get taskDetailGoodAttitude;

  /// No description provided for @taskDetailSkilled.
  ///
  /// In en, this message translates to:
  /// **'Skilled'**
  String get taskDetailSkilled;

  /// No description provided for @taskDetailTrustworthy.
  ///
  /// In en, this message translates to:
  /// **'Trustworthy'**
  String get taskDetailTrustworthy;

  /// No description provided for @taskDetailRecommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get taskDetailRecommended;

  /// No description provided for @taskDetailExcellent.
  ///
  /// In en, this message translates to:
  /// **'Excellent'**
  String get taskDetailExcellent;

  /// No description provided for @taskDetailTaskClear.
  ///
  /// In en, this message translates to:
  /// **'Clear Task'**
  String get taskDetailTaskClear;

  /// No description provided for @taskDetailCommunicationTimely.
  ///
  /// In en, this message translates to:
  /// **'Timely Communication'**
  String get taskDetailCommunicationTimely;

  /// No description provided for @taskDetailPaymentTimely.
  ///
  /// In en, this message translates to:
  /// **'Timely Payment'**
  String get taskDetailPaymentTimely;

  /// No description provided for @taskDetailReasonableRequirements.
  ///
  /// In en, this message translates to:
  /// **'Reasonable Requirements'**
  String get taskDetailReasonableRequirements;

  /// No description provided for @taskDetailPleasantCooperation.
  ///
  /// In en, this message translates to:
  /// **'Pleasant Cooperation'**
  String get taskDetailPleasantCooperation;

  /// No description provided for @taskDetailProfessionalEfficient.
  ///
  /// In en, this message translates to:
  /// **'Professional & Efficient'**
  String get taskDetailProfessionalEfficient;

  /// No description provided for @messagesLoadingMessages.
  ///
  /// In en, this message translates to:
  /// **'Loading messages...'**
  String get messagesLoadingMessages;

  /// No description provided for @messagesNoMessagesYet.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get messagesNoMessagesYet;

  /// No description provided for @messagesStartConversation.
  ///
  /// In en, this message translates to:
  /// **'Start a conversation!'**
  String get messagesStartConversation;

  /// No description provided for @messagesNoTaskChats.
  ///
  /// In en, this message translates to:
  /// **'No Task Chats'**
  String get messagesNoTaskChats;

  /// No description provided for @messagesNoTaskChatsMessage.
  ///
  /// In en, this message translates to:
  /// **'No task-related chat records yet'**
  String get messagesNoTaskChatsMessage;

  /// No description provided for @messagesCustomerService.
  ///
  /// In en, this message translates to:
  /// **'Customer Service'**
  String get messagesCustomerService;

  /// No description provided for @messagesContactService.
  ///
  /// In en, this message translates to:
  /// **'Contact customer service for help'**
  String get messagesContactService;

  /// No description provided for @messagesInteractionInfo.
  ///
  /// In en, this message translates to:
  /// **'Interaction Info'**
  String get messagesInteractionInfo;

  /// No description provided for @messagesViewForumInteractions.
  ///
  /// In en, this message translates to:
  /// **'View forum interaction messages'**
  String get messagesViewForumInteractions;

  /// No description provided for @messagesNoInteractions.
  ///
  /// In en, this message translates to:
  /// **'No Interactions'**
  String get messagesNoInteractions;

  /// No description provided for @messagesNoInteractionsMessage.
  ///
  /// In en, this message translates to:
  /// **'No interaction notifications yet'**
  String get messagesNoInteractionsMessage;

  /// No description provided for @messagesClickToView.
  ///
  /// In en, this message translates to:
  /// **'Click to view messages'**
  String get messagesClickToView;

  /// No description provided for @messagesLoadingMore.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get messagesLoadingMore;

  /// No description provided for @messagesLoadMoreHistory.
  ///
  /// In en, this message translates to:
  /// **'Load more history'**
  String get messagesLoadMoreHistory;

  /// No description provided for @permissionLocationUsageDescription.
  ///
  /// In en, this message translates to:
  /// **'We need to access your location information to provide you with more accurate services and task recommendations'**
  String get permissionLocationUsageDescription;

  /// No description provided for @customerServiceWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Customer Service'**
  String get customerServiceWelcome;

  /// No description provided for @customerServiceStartConversation.
  ///
  /// In en, this message translates to:
  /// **'Click the connect button below to start chatting with customer service'**
  String get customerServiceStartConversation;

  /// No description provided for @customerServiceLoadingMessages.
  ///
  /// In en, this message translates to:
  /// **'Loading messages...'**
  String get customerServiceLoadingMessages;

  /// No description provided for @customerServiceQueuePosition.
  ///
  /// In en, this message translates to:
  /// **'Queue Position: No. {param1}'**
  String customerServiceQueuePosition(int param1);

  /// No description provided for @customerServiceEstimatedWait.
  ///
  /// In en, this message translates to:
  /// **'Estimated Wait Time: {param1} seconds'**
  String customerServiceEstimatedWait(int param1);

  /// No description provided for @customerServiceConversationEnded.
  ///
  /// In en, this message translates to:
  /// **'Conversation ended'**
  String get customerServiceConversationEnded;

  /// No description provided for @customerServiceNewConversation.
  ///
  /// In en, this message translates to:
  /// **'New Conversation'**
  String get customerServiceNewConversation;

  /// No description provided for @customerServiceEnterMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter message...'**
  String get customerServiceEnterMessage;

  /// No description provided for @customerServiceConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting to customer service...'**
  String get customerServiceConnecting;

  /// No description provided for @customerServiceEndConversation.
  ///
  /// In en, this message translates to:
  /// **'End Conversation'**
  String get customerServiceEndConversation;

  /// No description provided for @customerServiceHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get customerServiceHistory;

  /// No description provided for @customerServiceLoginRequired.
  ///
  /// In en, this message translates to:
  /// **'Please login first to use customer service'**
  String get customerServiceLoginRequired;

  /// No description provided for @customerServiceWhatCanHelp.
  ///
  /// In en, this message translates to:
  /// **'How can we help you?'**
  String get customerServiceWhatCanHelp;

  /// No description provided for @customerServiceNoChatHistory.
  ///
  /// In en, this message translates to:
  /// **'No Chat History'**
  String get customerServiceNoChatHistory;

  /// No description provided for @customerServiceStartNewConversation.
  ///
  /// In en, this message translates to:
  /// **'Start a new conversation!'**
  String get customerServiceStartNewConversation;

  /// No description provided for @customerServiceChatHistory.
  ///
  /// In en, this message translates to:
  /// **'Chat History'**
  String get customerServiceChatHistory;

  /// No description provided for @customerServiceDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get customerServiceDone;

  /// No description provided for @customerServiceServiceChat.
  ///
  /// In en, this message translates to:
  /// **'Service Chat'**
  String get customerServiceServiceChat;

  /// No description provided for @customerServiceEnded.
  ///
  /// In en, this message translates to:
  /// **'Ended'**
  String get customerServiceEnded;

  /// No description provided for @customerServiceInProgress.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get customerServiceInProgress;

  /// No description provided for @customerServiceRateService.
  ///
  /// In en, this message translates to:
  /// **'Rate Service'**
  String get customerServiceRateService;

  /// No description provided for @customerServiceSatisfactionQuestion.
  ///
  /// In en, this message translates to:
  /// **'Are you satisfied with {param1}\'s service?'**
  String customerServiceSatisfactionQuestion(String param1);

  /// No description provided for @customerServiceSelectRating.
  ///
  /// In en, this message translates to:
  /// **'Please select a rating'**
  String get customerServiceSelectRating;

  /// No description provided for @customerServiceRatingContent.
  ///
  /// In en, this message translates to:
  /// **'Rating Content (Optional)'**
  String get customerServiceRatingContent;

  /// No description provided for @customerServiceSubmitRating.
  ///
  /// In en, this message translates to:
  /// **'Submit Rating'**
  String get customerServiceSubmitRating;

  /// No description provided for @customerServiceRateServiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Rate Service'**
  String get customerServiceRateServiceTitle;

  /// No description provided for @customerServiceSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get customerServiceSkip;

  /// No description provided for @ratingVeryPoor.
  ///
  /// In en, this message translates to:
  /// **'Very Poor'**
  String get ratingVeryPoor;

  /// No description provided for @ratingPoor.
  ///
  /// In en, this message translates to:
  /// **'Poor'**
  String get ratingPoor;

  /// No description provided for @ratingAverage.
  ///
  /// In en, this message translates to:
  /// **'Average'**
  String get ratingAverage;

  /// No description provided for @ratingGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get ratingGood;

  /// No description provided for @ratingExcellent.
  ///
  /// In en, this message translates to:
  /// **'Excellent'**
  String get ratingExcellent;

  /// No description provided for @ratingRating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get ratingRating;

  /// No description provided for @ratingSelectTags.
  ///
  /// In en, this message translates to:
  /// **'Select Tags (Optional)'**
  String get ratingSelectTags;

  /// No description provided for @ratingComment.
  ///
  /// In en, this message translates to:
  /// **'Comment (Optional)'**
  String get ratingComment;

  /// No description provided for @ratingAnonymous.
  ///
  /// In en, this message translates to:
  /// **'Anonymous Rating'**
  String get ratingAnonymous;

  /// No description provided for @ratingSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit Rating'**
  String get ratingSubmit;

  /// No description provided for @ratingSuccess.
  ///
  /// In en, this message translates to:
  /// **'Review submitted'**
  String get ratingSuccess;

  /// No description provided for @ratingAnonymousRating.
  ///
  /// In en, this message translates to:
  /// **'Anonymous Rating'**
  String get ratingAnonymousRating;

  /// No description provided for @ratingSubmitRating.
  ///
  /// In en, this message translates to:
  /// **'Submit Rating'**
  String get ratingSubmitRating;

  /// No description provided for @ratingHalfStar.
  ///
  /// In en, this message translates to:
  /// **'{param1} stars'**
  String ratingHalfStar(String param1);

  /// No description provided for @rating05Stars.
  ///
  /// In en, this message translates to:
  /// **'0.5 stars'**
  String get rating05Stars;

  /// No description provided for @rating15Stars.
  ///
  /// In en, this message translates to:
  /// **'1.5 stars'**
  String get rating15Stars;

  /// No description provided for @rating25Stars.
  ///
  /// In en, this message translates to:
  /// **'2.5 stars'**
  String get rating25Stars;

  /// No description provided for @rating35Stars.
  ///
  /// In en, this message translates to:
  /// **'3.5 stars'**
  String get rating35Stars;

  /// No description provided for @rating45Stars.
  ///
  /// In en, this message translates to:
  /// **'4.5 stars'**
  String get rating45Stars;

  /// No description provided for @ratingTagHighQuality.
  ///
  /// In en, this message translates to:
  /// **'High Quality'**
  String get ratingTagHighQuality;

  /// No description provided for @ratingTagOnTime.
  ///
  /// In en, this message translates to:
  /// **'On Time'**
  String get ratingTagOnTime;

  /// No description provided for @ratingTagResponsible.
  ///
  /// In en, this message translates to:
  /// **'Responsible'**
  String get ratingTagResponsible;

  /// No description provided for @ratingTagGoodCommunication.
  ///
  /// In en, this message translates to:
  /// **'Good Communication'**
  String get ratingTagGoodCommunication;

  /// No description provided for @ratingTagProfessionalEfficient.
  ///
  /// In en, this message translates to:
  /// **'Professional & Efficient'**
  String get ratingTagProfessionalEfficient;

  /// No description provided for @ratingTagTrustworthy.
  ///
  /// In en, this message translates to:
  /// **'Trustworthy'**
  String get ratingTagTrustworthy;

  /// No description provided for @ratingTagStronglyRecommended.
  ///
  /// In en, this message translates to:
  /// **'Strongly Recommended'**
  String get ratingTagStronglyRecommended;

  /// No description provided for @ratingTagExcellent.
  ///
  /// In en, this message translates to:
  /// **'Excellent'**
  String get ratingTagExcellent;

  /// No description provided for @ratingTagClearTask.
  ///
  /// In en, this message translates to:
  /// **'Clear Task Description'**
  String get ratingTagClearTask;

  /// No description provided for @ratingTagTimelyCommunication.
  ///
  /// In en, this message translates to:
  /// **'Timely Communication'**
  String get ratingTagTimelyCommunication;

  /// No description provided for @ratingTagTimelyPayment.
  ///
  /// In en, this message translates to:
  /// **'Timely Payment'**
  String get ratingTagTimelyPayment;

  /// No description provided for @ratingTagReasonableRequirements.
  ///
  /// In en, this message translates to:
  /// **'Reasonable Requirements'**
  String get ratingTagReasonableRequirements;

  /// No description provided for @ratingTagPleasantCooperation.
  ///
  /// In en, this message translates to:
  /// **'Pleasant Cooperation'**
  String get ratingTagPleasantCooperation;

  /// No description provided for @ratingTagVeryProfessional.
  ///
  /// In en, this message translates to:
  /// **'Very Professional'**
  String get ratingTagVeryProfessional;

  /// No description provided for @taskApplicationApplyTask.
  ///
  /// In en, this message translates to:
  /// **'Apply for Task'**
  String get taskApplicationApplyTask;

  /// No description provided for @taskApplicationIWantToNegotiatePrice.
  ///
  /// In en, this message translates to:
  /// **'I want to negotiate price'**
  String get taskApplicationIWantToNegotiatePrice;

  /// No description provided for @taskApplicationExpectedAmount.
  ///
  /// In en, this message translates to:
  /// **'Expected Amount'**
  String get taskApplicationExpectedAmount;

  /// No description provided for @taskApplicationNegotiatePriceHint.
  ///
  /// In en, this message translates to:
  /// **'Tip: Negotiating price may affect the publisher\'s choice.'**
  String get taskApplicationNegotiatePriceHint;

  /// No description provided for @taskApplicationSubmitApplication.
  ///
  /// In en, this message translates to:
  /// **'Submit Application'**
  String get taskApplicationSubmitApplication;

  /// No description provided for @taskApplicationMessageToApplicant.
  ///
  /// In en, this message translates to:
  /// **'Message to applicant...'**
  String get taskApplicationMessageToApplicant;

  /// No description provided for @taskApplicationIsNegotiatePrice.
  ///
  /// In en, this message translates to:
  /// **'Is Negotiate Price'**
  String get taskApplicationIsNegotiatePrice;

  /// No description provided for @taskApplicationNegotiateAmount.
  ///
  /// In en, this message translates to:
  /// **'Negotiate Amount'**
  String get taskApplicationNegotiateAmount;

  /// No description provided for @taskApplicationSendMessage.
  ///
  /// In en, this message translates to:
  /// **'Send Message'**
  String get taskApplicationSendMessage;

  /// No description provided for @taskApplicationUnknownUser.
  ///
  /// In en, this message translates to:
  /// **'Unknown User'**
  String get taskApplicationUnknownUser;

  /// No description provided for @taskApplicationAdvantagePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Briefly explain your advantages or how to complete the task...'**
  String get taskApplicationAdvantagePlaceholder;

  /// No description provided for @taskApplicationReviewPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Write about your collaboration experience to help other users...'**
  String get taskApplicationReviewPlaceholder;

  /// No description provided for @emptyNoTasks.
  ///
  /// In en, this message translates to:
  /// **'No Tasks'**
  String get emptyNoTasks;

  /// No description provided for @emptyNoTasksMessage.
  ///
  /// In en, this message translates to:
  /// **'No tasks have been posted yet. Be the first to post one!'**
  String get emptyNoTasksMessage;

  /// No description provided for @emptyNoNotifications.
  ///
  /// In en, this message translates to:
  /// **'No Notifications'**
  String get emptyNoNotifications;

  /// No description provided for @emptyNoNotificationsMessage.
  ///
  /// In en, this message translates to:
  /// **'No notification messages received yet'**
  String get emptyNoNotificationsMessage;

  /// No description provided for @emptyNoPaymentRecords.
  ///
  /// In en, this message translates to:
  /// **'No Payment Records'**
  String get emptyNoPaymentRecords;

  /// No description provided for @emptyNoPaymentRecordsMessage.
  ///
  /// In en, this message translates to:
  /// **'Your payment records will be displayed here'**
  String get emptyNoPaymentRecordsMessage;

  /// No description provided for @paymentStatusSuccess.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get paymentStatusSuccess;

  /// No description provided for @paymentStatusProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get paymentStatusProcessing;

  /// No description provided for @paymentStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get paymentStatusFailed;

  /// No description provided for @paymentStatusCanceled.
  ///
  /// In en, this message translates to:
  /// **'Canceled'**
  String get paymentStatusCanceled;

  /// No description provided for @paymentStatusTaskPayment.
  ///
  /// In en, this message translates to:
  /// **'Task Payment'**
  String get paymentStatusTaskPayment;

  /// No description provided for @paymentTaskNumberWithId.
  ///
  /// In en, this message translates to:
  /// **'Task #{param1}'**
  String paymentTaskNumberWithId(int param1);

  /// No description provided for @notificationSystemMessages.
  ///
  /// In en, this message translates to:
  /// **'System Messages'**
  String get notificationSystemMessages;

  /// No description provided for @notificationViewAllNotifications.
  ///
  /// In en, this message translates to:
  /// **'View All Notifications'**
  String get notificationViewAllNotifications;

  /// No description provided for @customerServiceConversationEndedMessage.
  ///
  /// In en, this message translates to:
  /// **'Conversation ended. Please start a new conversation if you need help.'**
  String get customerServiceConversationEndedMessage;

  /// No description provided for @customerServiceConnected.
  ///
  /// In en, this message translates to:
  /// **'👋 Connected to customer service {param1}'**
  String customerServiceConnected(String param1);

  /// No description provided for @customerServiceTotalMessages.
  ///
  /// In en, this message translates to:
  /// **'{param1} messages'**
  String customerServiceTotalMessages(int param1);

  /// No description provided for @paymentRecordsPaymentRecords.
  ///
  /// In en, this message translates to:
  /// **'Payment Records'**
  String get paymentRecordsPaymentRecords;

  /// No description provided for @paymentRecordsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get paymentRecordsLoading;

  /// No description provided for @paymentRecordsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Load Failed'**
  String get paymentRecordsLoadFailed;

  /// No description provided for @paymentNoPayoutRecords.
  ///
  /// In en, this message translates to:
  /// **'No Payout Records'**
  String get paymentNoPayoutRecords;

  /// No description provided for @paymentNoPayoutRecordsMessage.
  ///
  /// In en, this message translates to:
  /// **'Your payout records will be displayed here'**
  String get paymentNoPayoutRecordsMessage;

  /// No description provided for @paymentViewDetails.
  ///
  /// In en, this message translates to:
  /// **'View Details'**
  String get paymentViewDetails;

  /// No description provided for @paymentPayout.
  ///
  /// In en, this message translates to:
  /// **'Payout'**
  String get paymentPayout;

  /// No description provided for @paymentNoAvailableBalance.
  ///
  /// In en, this message translates to:
  /// **'No Available Balance'**
  String get paymentNoAvailableBalance;

  /// No description provided for @paymentPayoutRecords.
  ///
  /// In en, this message translates to:
  /// **'Payout Records'**
  String get paymentPayoutRecords;

  /// No description provided for @paymentTotalBalance.
  ///
  /// In en, this message translates to:
  /// **'Total Balance'**
  String get paymentTotalBalance;

  /// No description provided for @paymentAvailableBalance.
  ///
  /// In en, this message translates to:
  /// **'Available Balance'**
  String get paymentAvailableBalance;

  /// No description provided for @paymentPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get paymentPending;

  /// No description provided for @paymentPayoutAmount.
  ///
  /// In en, this message translates to:
  /// **'Payout Amount'**
  String get paymentPayoutAmount;

  /// No description provided for @paymentPayoutAmountTitle.
  ///
  /// In en, this message translates to:
  /// **'Payout Amount'**
  String get paymentPayoutAmountTitle;

  /// No description provided for @paymentIncomeAmount.
  ///
  /// In en, this message translates to:
  /// **'Income Amount'**
  String get paymentIncomeAmount;

  /// No description provided for @paymentNoteOptional.
  ///
  /// In en, this message translates to:
  /// **'Note (Optional)'**
  String get paymentNoteOptional;

  /// No description provided for @paymentPayoutNote.
  ///
  /// In en, this message translates to:
  /// **'Payout Note'**
  String get paymentPayoutNote;

  /// No description provided for @paymentConfirmPayout.
  ///
  /// In en, this message translates to:
  /// **'Confirm Payout'**
  String get paymentConfirmPayout;

  /// No description provided for @paymentAccountInfo.
  ///
  /// In en, this message translates to:
  /// **'Account Info'**
  String get paymentAccountInfo;

  /// No description provided for @paymentAccountDetails.
  ///
  /// In en, this message translates to:
  /// **'Account Details'**
  String get paymentAccountDetails;

  /// No description provided for @paymentOpenStripeDashboard.
  ///
  /// In en, this message translates to:
  /// **'Open Stripe Dashboard'**
  String get paymentOpenStripeDashboard;

  /// No description provided for @paymentExternalAccount.
  ///
  /// In en, this message translates to:
  /// **'External Account'**
  String get paymentExternalAccount;

  /// No description provided for @paymentNoExternalAccount.
  ///
  /// In en, this message translates to:
  /// **'No External Account'**
  String get paymentNoExternalAccount;

  /// No description provided for @paymentDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get paymentDetails;

  /// No description provided for @paymentAccountId.
  ///
  /// In en, this message translates to:
  /// **'Account ID'**
  String get paymentAccountId;

  /// No description provided for @paymentDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Display Name'**
  String get paymentDisplayName;

  /// No description provided for @paymentCountry.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get paymentCountry;

  /// No description provided for @paymentAccountType.
  ///
  /// In en, this message translates to:
  /// **'Account Type'**
  String get paymentAccountType;

  /// No description provided for @paymentDetailsSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Details Submitted'**
  String get paymentDetailsSubmitted;

  /// No description provided for @paymentChargesEnabled.
  ///
  /// In en, this message translates to:
  /// **'Charges Enabled'**
  String get paymentChargesEnabled;

  /// No description provided for @paymentPayoutsEnabled.
  ///
  /// In en, this message translates to:
  /// **'Payouts Enabled'**
  String get paymentPayoutsEnabled;

  /// No description provided for @paymentYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get paymentYes;

  /// No description provided for @paymentNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get paymentNo;

  /// No description provided for @paymentBankAccount.
  ///
  /// In en, this message translates to:
  /// **'Bank Account'**
  String get paymentBankAccount;

  /// No description provided for @paymentCard.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get paymentCard;

  /// No description provided for @paymentBankName.
  ///
  /// In en, this message translates to:
  /// **'Bank Name'**
  String get paymentBankName;

  /// No description provided for @paymentAccountLast4.
  ///
  /// In en, this message translates to:
  /// **'Account Last 4'**
  String get paymentAccountLast4;

  /// No description provided for @paymentRoutingNumber.
  ///
  /// In en, this message translates to:
  /// **'Routing Number'**
  String get paymentRoutingNumber;

  /// No description provided for @paymentAccountHolder.
  ///
  /// In en, this message translates to:
  /// **'Account Holder'**
  String get paymentAccountHolder;

  /// No description provided for @paymentHolderType.
  ///
  /// In en, this message translates to:
  /// **'Holder Type'**
  String get paymentHolderType;

  /// No description provided for @paymentIndividual.
  ///
  /// In en, this message translates to:
  /// **'Individual'**
  String get paymentIndividual;

  /// No description provided for @paymentCompany.
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get paymentCompany;

  /// No description provided for @paymentStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get paymentStatus;

  /// No description provided for @paymentCardBrand.
  ///
  /// In en, this message translates to:
  /// **'Card Brand'**
  String get paymentCardBrand;

  /// No description provided for @paymentCardLast4.
  ///
  /// In en, this message translates to:
  /// **'Card Last 4'**
  String get paymentCardLast4;

  /// No description provided for @paymentExpiry.
  ///
  /// In en, this message translates to:
  /// **'Expiry'**
  String get paymentExpiry;

  /// No description provided for @paymentCardType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get paymentCardType;

  /// No description provided for @paymentCreditCard.
  ///
  /// In en, this message translates to:
  /// **'Credit Card'**
  String get paymentCreditCard;

  /// No description provided for @paymentDebitCard.
  ///
  /// In en, this message translates to:
  /// **'Debit Card'**
  String get paymentDebitCard;

  /// No description provided for @paymentTransactionId.
  ///
  /// In en, this message translates to:
  /// **'Transaction ID'**
  String get paymentTransactionId;

  /// No description provided for @paymentDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get paymentDescription;

  /// No description provided for @paymentTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get paymentTime;

  /// No description provided for @paymentType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get paymentType;

  /// No description provided for @paymentIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get paymentIncome;

  /// No description provided for @paymentSource.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get paymentSource;

  /// No description provided for @paymentPayoutManagement.
  ///
  /// In en, this message translates to:
  /// **'Payout Management'**
  String get paymentPayoutManagement;

  /// No description provided for @paymentTransactionDetails.
  ///
  /// In en, this message translates to:
  /// **'Transaction Details'**
  String get paymentTransactionDetails;

  /// No description provided for @paymentAccountSetupComplete.
  ///
  /// In en, this message translates to:
  /// **'Payment Account Setup Complete'**
  String get paymentAccountSetupComplete;

  /// No description provided for @paymentCanReceiveRewards.
  ///
  /// In en, this message translates to:
  /// **'You can now receive task rewards'**
  String get paymentCanReceiveRewards;

  /// No description provided for @paymentAccountInfoBelow.
  ///
  /// In en, this message translates to:
  /// **'Your account information is as follows'**
  String get paymentAccountInfoBelow;

  /// No description provided for @paymentRefreshAccountInfo.
  ///
  /// In en, this message translates to:
  /// **'Refresh Account Info'**
  String get paymentRefreshAccountInfo;

  /// No description provided for @paymentComplete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get paymentComplete;

  /// No description provided for @paymentCountdownExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get paymentCountdownExpired;

  /// No description provided for @paymentCountdownRemaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining {time}'**
  String paymentCountdownRemaining(String time);

  /// No description provided for @paymentCountdownBannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Complete payment within 30 minutes'**
  String get paymentCountdownBannerTitle;

  /// No description provided for @paymentCountdownBannerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Time remaining: {param1}'**
  String paymentCountdownBannerSubtitle(String param1);

  /// No description provided for @paymentCountdownBannerExpired.
  ///
  /// In en, this message translates to:
  /// **'Payment expired, task will be cancelled'**
  String get paymentCountdownBannerExpired;

  /// No description provided for @couponMinAmountAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available for {param1} or more'**
  String couponMinAmountAvailable(String param1);

  /// No description provided for @couponAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get couponAvailable;

  /// No description provided for @couponDiscount.
  ///
  /// In en, this message translates to:
  /// **'{param1}% Off'**
  String couponDiscount(int param1);

  /// No description provided for @couponMyCoupons.
  ///
  /// In en, this message translates to:
  /// **'My Coupons'**
  String get couponMyCoupons;

  /// No description provided for @couponNoThreshold.
  ///
  /// In en, this message translates to:
  /// **'No Threshold'**
  String get couponNoThreshold;

  /// No description provided for @couponClaimNow.
  ///
  /// In en, this message translates to:
  /// **'Claim Now'**
  String get couponClaimNow;

  /// No description provided for @couponAvailableCoupons.
  ///
  /// In en, this message translates to:
  /// **'Available Coupons'**
  String get couponAvailableCoupons;

  /// No description provided for @couponRedeemSuccess.
  ///
  /// In en, this message translates to:
  /// **'Redeem Success'**
  String get couponRedeemSuccess;

  /// No description provided for @couponRedeemFailed.
  ///
  /// In en, this message translates to:
  /// **'Redeem Failed'**
  String get couponRedeemFailed;

  /// No description provided for @couponEnterRedemptionCode.
  ///
  /// In en, this message translates to:
  /// **'Enter Redemption Code'**
  String get couponEnterRedemptionCode;

  /// No description provided for @couponEnterRedemptionCodePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Please enter redemption code'**
  String get couponEnterRedemptionCodePlaceholder;

  /// No description provided for @couponRedeem.
  ///
  /// In en, this message translates to:
  /// **'Redeem'**
  String get couponRedeem;

  /// No description provided for @couponConfirmRedeem.
  ///
  /// In en, this message translates to:
  /// **'Confirm Redeem'**
  String get couponConfirmRedeem;

  /// No description provided for @couponConfirmRedeemWithPoints.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to redeem this coupon with {param1} points?'**
  String couponConfirmRedeemWithPoints(int param1);

  /// No description provided for @couponValidUntil.
  ///
  /// In en, this message translates to:
  /// **'Valid Until: {param1}'**
  String couponValidUntil(String param1);

  /// No description provided for @couponNoAvailableCoupons.
  ///
  /// In en, this message translates to:
  /// **'No Available Coupons'**
  String get couponNoAvailableCoupons;

  /// No description provided for @couponNoAvailableCouponsMessage.
  ///
  /// In en, this message translates to:
  /// **'No coupons available to claim, stay tuned for events'**
  String get couponNoAvailableCouponsMessage;

  /// No description provided for @couponNoMyCoupons.
  ///
  /// In en, this message translates to:
  /// **'You have no coupons yet'**
  String get couponNoMyCoupons;

  /// No description provided for @couponNoMyCouponsMessage.
  ///
  /// In en, this message translates to:
  /// **'Claimed coupons will appear here'**
  String get couponNoMyCouponsMessage;

  /// No description provided for @couponUsageInstructions.
  ///
  /// In en, this message translates to:
  /// **'Usage Instructions'**
  String get couponUsageInstructions;

  /// No description provided for @couponTransactionHistory.
  ///
  /// In en, this message translates to:
  /// **'Transaction History'**
  String get couponTransactionHistory;

  /// No description provided for @couponCheckInReward.
  ///
  /// In en, this message translates to:
  /// **'Check-in Rewards'**
  String get couponCheckInReward;

  /// No description provided for @couponCheckInComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Check-in rewards coming soon, stay tuned'**
  String get couponCheckInComingSoon;

  /// No description provided for @couponCheckInSuccess.
  ///
  /// In en, this message translates to:
  /// **'Check-in Successful'**
  String get couponCheckInSuccess;

  /// No description provided for @couponAwesome.
  ///
  /// In en, this message translates to:
  /// **'Awesome'**
  String get couponAwesome;

  /// No description provided for @couponDays.
  ///
  /// In en, this message translates to:
  /// **'{param1} days'**
  String couponDays(int param1);

  /// No description provided for @couponRememberTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Remember to come back tomorrow'**
  String get couponRememberTomorrow;

  /// No description provided for @couponConsecutiveReward.
  ///
  /// In en, this message translates to:
  /// **'More consecutive days, more rewards'**
  String get couponConsecutiveReward;

  /// No description provided for @couponCheckInNow.
  ///
  /// In en, this message translates to:
  /// **'Check In Now'**
  String get couponCheckInNow;

  /// No description provided for @couponConsecutiveDays.
  ///
  /// In en, this message translates to:
  /// **'Consecutive check-in for {param1} days'**
  String couponConsecutiveDays(int param1);

  /// No description provided for @couponConsecutiveCheckIn.
  ///
  /// In en, this message translates to:
  /// **'{days}-day streak'**
  String couponConsecutiveCheckIn(int days);

  /// No description provided for @couponMemberOnly.
  ///
  /// In en, this message translates to:
  /// **'Member Only'**
  String get couponMemberOnly;

  /// No description provided for @couponLimitPerDay.
  ///
  /// In en, this message translates to:
  /// **'{param1} per day'**
  String couponLimitPerDay(int param1);

  /// No description provided for @couponLimitPerWeek.
  ///
  /// In en, this message translates to:
  /// **'{param1} per week'**
  String couponLimitPerWeek(int param1);

  /// No description provided for @couponLimitPerMonth.
  ///
  /// In en, this message translates to:
  /// **'{param1} per month'**
  String couponLimitPerMonth(int param1);

  /// No description provided for @couponLimitPerYear.
  ///
  /// In en, this message translates to:
  /// **'{param1} per year'**
  String couponLimitPerYear(int param1);

  /// No description provided for @taskApplicationApplyInfo.
  ///
  /// In en, this message translates to:
  /// **'Application Info'**
  String get taskApplicationApplyInfo;

  /// No description provided for @taskApplicationOverallRating.
  ///
  /// In en, this message translates to:
  /// **'Overall Rating'**
  String get taskApplicationOverallRating;

  /// No description provided for @taskApplicationRatingTags.
  ///
  /// In en, this message translates to:
  /// **'Rating Tags'**
  String get taskApplicationRatingTags;

  /// No description provided for @taskApplicationRatingContent.
  ///
  /// In en, this message translates to:
  /// **'Rating Content'**
  String get taskApplicationRatingContent;

  /// No description provided for @createTaskPublishing.
  ///
  /// In en, this message translates to:
  /// **'Publishing...'**
  String get createTaskPublishing;

  /// No description provided for @createTaskPublishNow.
  ///
  /// In en, this message translates to:
  /// **'Publish Task Now'**
  String get createTaskPublishNow;

  /// No description provided for @createTaskPublishTask.
  ///
  /// In en, this message translates to:
  /// **'Publish Task'**
  String get createTaskPublishTask;

  /// No description provided for @createTaskTitle.
  ///
  /// In en, this message translates to:
  /// **'Post Task'**
  String get createTaskTitle;

  /// No description provided for @createTaskTitlePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Enter task title'**
  String get createTaskTitlePlaceholder;

  /// No description provided for @createTaskDescription.
  ///
  /// In en, this message translates to:
  /// **'Task Details'**
  String get createTaskDescription;

  /// No description provided for @createTaskDescriptionPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Please describe your needs, time, special requirements, etc. in detail. The more detailed, the easier it is to get accepted...'**
  String get createTaskDescriptionPlaceholder;

  /// No description provided for @createTaskReward.
  ///
  /// In en, this message translates to:
  /// **'Reward'**
  String get createTaskReward;

  /// No description provided for @createTaskCity.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get createTaskCity;

  /// No description provided for @createTaskOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get createTaskOnline;

  /// No description provided for @createTaskCampusLifeRestriction.
  ///
  /// In en, this message translates to:
  /// **'Only verified students can post campus life tasks'**
  String get createTaskCampusLifeRestriction;

  /// No description provided for @studentVerificationStudentVerification.
  ///
  /// In en, this message translates to:
  /// **'Student Verification'**
  String get studentVerificationStudentVerification;

  /// No description provided for @stripeConnectSetupAccount.
  ///
  /// In en, this message translates to:
  /// **'Setup Payment Account'**
  String get stripeConnectSetupAccount;

  /// No description provided for @activityLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Load Failed'**
  String get activityLoadFailed;

  /// No description provided for @activityPleaseRetry.
  ///
  /// In en, this message translates to:
  /// **'Please retry'**
  String get activityPleaseRetry;

  /// No description provided for @activityDescription.
  ///
  /// In en, this message translates to:
  /// **'Activity Description'**
  String get activityDescription;

  /// No description provided for @activityDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get activityDetails;

  /// No description provided for @activitySelectTimeSlot.
  ///
  /// In en, this message translates to:
  /// **'Select Time Slot'**
  String get activitySelectTimeSlot;

  /// No description provided for @activityNoAvailableTime.
  ///
  /// In en, this message translates to:
  /// **'No Available Time'**
  String get activityNoAvailableTime;

  /// No description provided for @activityNoAvailableTimeMessage.
  ///
  /// In en, this message translates to:
  /// **'No available time slots at the moment'**
  String get activityNoAvailableTimeMessage;

  /// No description provided for @activityParticipateTime.
  ///
  /// In en, this message translates to:
  /// **'Participate Time'**
  String get activityParticipateTime;

  /// No description provided for @activityByAppointment.
  ///
  /// In en, this message translates to:
  /// **'By Appointment'**
  String get activityByAppointment;

  /// No description provided for @activityParticipants.
  ///
  /// In en, this message translates to:
  /// **'Participants'**
  String get activityParticipants;

  /// No description provided for @activityRemainingSlots.
  ///
  /// In en, this message translates to:
  /// **'Remaining Slots'**
  String get activityRemainingSlots;

  /// No description provided for @activityStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get activityStatus;

  /// No description provided for @activityHotRecruiting.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get activityHotRecruiting;

  /// No description provided for @activityLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get activityLocation;

  /// No description provided for @activityType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get activityType;

  /// No description provided for @activityTimeArrangement.
  ///
  /// In en, this message translates to:
  /// **'Time Arrangement'**
  String get activityTimeArrangement;

  /// No description provided for @activityMultipleTimeSlots.
  ///
  /// In en, this message translates to:
  /// **'Supports multiple time slot bookings'**
  String get activityMultipleTimeSlots;

  /// No description provided for @activityDeadline.
  ///
  /// In en, this message translates to:
  /// **'Deadline'**
  String get activityDeadline;

  /// No description provided for @activityExclusiveDiscount.
  ///
  /// In en, this message translates to:
  /// **'Exclusive Discount'**
  String get activityExclusiveDiscount;

  /// No description provided for @activityFilter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get activityFilter;

  /// No description provided for @activityAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get activityAll;

  /// No description provided for @activityActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get activityActive;

  /// No description provided for @activitySingle.
  ///
  /// In en, this message translates to:
  /// **'Single'**
  String get activitySingle;

  /// No description provided for @activityMulti.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get activityMulti;

  /// No description provided for @activityTabAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get activityTabAll;

  /// No description provided for @activityTabApplied.
  ///
  /// In en, this message translates to:
  /// **'Applied'**
  String get activityTabApplied;

  /// No description provided for @activityTabFavorited.
  ///
  /// In en, this message translates to:
  /// **'Favorited'**
  String get activityTabFavorited;

  /// No description provided for @activityActivities.
  ///
  /// In en, this message translates to:
  /// **'Activities'**
  String get activityActivities;

  /// No description provided for @activityNoEndedActivities.
  ///
  /// In en, this message translates to:
  /// **'No Ended Activities'**
  String get activityNoEndedActivities;

  /// No description provided for @activityNoEndedActivitiesMessage.
  ///
  /// In en, this message translates to:
  /// **'No ended activity records'**
  String get activityNoEndedActivitiesMessage;

  /// No description provided for @activityNoActivities.
  ///
  /// In en, this message translates to:
  /// **'No Activities'**
  String get activityNoActivities;

  /// No description provided for @activityNoActivitiesMessage.
  ///
  /// In en, this message translates to:
  /// **'No activities yet, stay tuned...'**
  String get activityNoActivitiesMessage;

  /// No description provided for @activityFullCapacity.
  ///
  /// In en, this message translates to:
  /// **'Full Capacity'**
  String get activityFullCapacity;

  /// No description provided for @activityPoster.
  ///
  /// In en, this message translates to:
  /// **'Activity Poster'**
  String get activityPoster;

  /// No description provided for @activityViewExpertProfile.
  ///
  /// In en, this message translates to:
  /// **'View Expert Profile'**
  String get activityViewExpertProfile;

  /// No description provided for @activityFavorite.
  ///
  /// In en, this message translates to:
  /// **'Favorite'**
  String get activityFavorite;

  /// No description provided for @activityTimeFlexible.
  ///
  /// In en, this message translates to:
  /// **'Flexible Time'**
  String get activityTimeFlexible;

  /// No description provided for @activityPreferredDate.
  ///
  /// In en, this message translates to:
  /// **'Preferred Date'**
  String get activityPreferredDate;

  /// No description provided for @activityTimeFlexibleMessage.
  ///
  /// In en, this message translates to:
  /// **'If you are available at any time in the near future'**
  String get activityTimeFlexibleMessage;

  /// No description provided for @activityConfirmApply.
  ///
  /// In en, this message translates to:
  /// **'Confirm Application'**
  String get activityConfirmApply;

  /// No description provided for @taskTypeSuperTask.
  ///
  /// In en, this message translates to:
  /// **'Super Task'**
  String get taskTypeSuperTask;

  /// No description provided for @taskTypeVipTask.
  ///
  /// In en, this message translates to:
  /// **'VIP Task'**
  String get taskTypeVipTask;

  /// No description provided for @menuMenu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get menuMenu;

  /// No description provided for @menuMy.
  ///
  /// In en, this message translates to:
  /// **'My'**
  String get menuMy;

  /// No description provided for @menuTaskHall.
  ///
  /// In en, this message translates to:
  /// **'Task Hall'**
  String get menuTaskHall;

  /// No description provided for @menuTaskExperts.
  ///
  /// In en, this message translates to:
  /// **'Task Experts'**
  String get menuTaskExperts;

  /// No description provided for @menuForum.
  ///
  /// In en, this message translates to:
  /// **'Forum'**
  String get menuForum;

  /// No description provided for @menuLeaderboard.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get menuLeaderboard;

  /// No description provided for @menuFleaMarket.
  ///
  /// In en, this message translates to:
  /// **'Flea Market'**
  String get menuFleaMarket;

  /// No description provided for @menuActivity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get menuActivity;

  /// No description provided for @menuPointsCoupons.
  ///
  /// In en, this message translates to:
  /// **'Points & Coupons'**
  String get menuPointsCoupons;

  /// No description provided for @menuStudentVerification.
  ///
  /// In en, this message translates to:
  /// **'Student Verification'**
  String get menuStudentVerification;

  /// No description provided for @menuSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get menuSettings;

  /// No description provided for @menuClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get menuClose;

  /// No description provided for @taskCategoryAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get taskCategoryAll;

  /// No description provided for @taskCategoryHousekeeping.
  ///
  /// In en, this message translates to:
  /// **'Housekeeping'**
  String get taskCategoryHousekeeping;

  /// No description provided for @taskCategoryCampusLife.
  ///
  /// In en, this message translates to:
  /// **'Campus Life'**
  String get taskCategoryCampusLife;

  /// No description provided for @taskCategorySecondhandRental.
  ///
  /// In en, this message translates to:
  /// **'Secondhand'**
  String get taskCategorySecondhandRental;

  /// No description provided for @taskCategoryErrandRunning.
  ///
  /// In en, this message translates to:
  /// **'Errands'**
  String get taskCategoryErrandRunning;

  /// No description provided for @taskCategorySkillService.
  ///
  /// In en, this message translates to:
  /// **'Skills'**
  String get taskCategorySkillService;

  /// No description provided for @taskCategorySocialHelp.
  ///
  /// In en, this message translates to:
  /// **'Social Help'**
  String get taskCategorySocialHelp;

  /// No description provided for @taskCategoryTransportation.
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get taskCategoryTransportation;

  /// No description provided for @taskCategoryPetCare.
  ///
  /// In en, this message translates to:
  /// **'Pet Care'**
  String get taskCategoryPetCare;

  /// No description provided for @taskCategoryLifeConvenience.
  ///
  /// In en, this message translates to:
  /// **'Convenience'**
  String get taskCategoryLifeConvenience;

  /// No description provided for @taskCategoryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get taskCategoryOther;

  /// No description provided for @expertCategoryAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get expertCategoryAll;

  /// No description provided for @expertCategoryProgramming.
  ///
  /// In en, this message translates to:
  /// **'Programming'**
  String get expertCategoryProgramming;

  /// No description provided for @expertCategoryTranslation.
  ///
  /// In en, this message translates to:
  /// **'Translation'**
  String get expertCategoryTranslation;

  /// No description provided for @expertCategoryTutoring.
  ///
  /// In en, this message translates to:
  /// **'Tutoring'**
  String get expertCategoryTutoring;

  /// No description provided for @expertCategoryFood.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get expertCategoryFood;

  /// No description provided for @expertCategoryBeverage.
  ///
  /// In en, this message translates to:
  /// **'Beverage'**
  String get expertCategoryBeverage;

  /// No description provided for @expertCategoryCake.
  ///
  /// In en, this message translates to:
  /// **'Cake'**
  String get expertCategoryCake;

  /// No description provided for @expertCategoryErrandTransport.
  ///
  /// In en, this message translates to:
  /// **'Errand/Transport'**
  String get expertCategoryErrandTransport;

  /// No description provided for @expertCategorySocialEntertainment.
  ///
  /// In en, this message translates to:
  /// **'Social/Entertainment'**
  String get expertCategorySocialEntertainment;

  /// No description provided for @expertCategoryBeautySkincare.
  ///
  /// In en, this message translates to:
  /// **'Beauty/Skincare'**
  String get expertCategoryBeautySkincare;

  /// No description provided for @expertCategoryHandicraft.
  ///
  /// In en, this message translates to:
  /// **'Handicraft'**
  String get expertCategoryHandicraft;

  /// No description provided for @cityLondon.
  ///
  /// In en, this message translates to:
  /// **'London'**
  String get cityLondon;

  /// No description provided for @cityEdinburgh.
  ///
  /// In en, this message translates to:
  /// **'Edinburgh'**
  String get cityEdinburgh;

  /// No description provided for @cityManchester.
  ///
  /// In en, this message translates to:
  /// **'Manchester'**
  String get cityManchester;

  /// No description provided for @cityBirmingham.
  ///
  /// In en, this message translates to:
  /// **'Birmingham'**
  String get cityBirmingham;

  /// No description provided for @cityGlasgow.
  ///
  /// In en, this message translates to:
  /// **'Glasgow'**
  String get cityGlasgow;

  /// No description provided for @cityBristol.
  ///
  /// In en, this message translates to:
  /// **'Bristol'**
  String get cityBristol;

  /// No description provided for @citySheffield.
  ///
  /// In en, this message translates to:
  /// **'Sheffield'**
  String get citySheffield;

  /// No description provided for @cityLeeds.
  ///
  /// In en, this message translates to:
  /// **'Leeds'**
  String get cityLeeds;

  /// No description provided for @cityNottingham.
  ///
  /// In en, this message translates to:
  /// **'Nottingham'**
  String get cityNottingham;

  /// No description provided for @cityNewcastle.
  ///
  /// In en, this message translates to:
  /// **'Newcastle'**
  String get cityNewcastle;

  /// No description provided for @citySouthampton.
  ///
  /// In en, this message translates to:
  /// **'Southampton'**
  String get citySouthampton;

  /// No description provided for @cityLiverpool.
  ///
  /// In en, this message translates to:
  /// **'Liverpool'**
  String get cityLiverpool;

  /// No description provided for @cityCardiff.
  ///
  /// In en, this message translates to:
  /// **'Cardiff'**
  String get cityCardiff;

  /// No description provided for @cityCoventry.
  ///
  /// In en, this message translates to:
  /// **'Coventry'**
  String get cityCoventry;

  /// No description provided for @cityExeter.
  ///
  /// In en, this message translates to:
  /// **'Exeter'**
  String get cityExeter;

  /// No description provided for @cityLeicester.
  ///
  /// In en, this message translates to:
  /// **'Leicester'**
  String get cityLeicester;

  /// No description provided for @cityYork.
  ///
  /// In en, this message translates to:
  /// **'York'**
  String get cityYork;

  /// No description provided for @cityAberdeen.
  ///
  /// In en, this message translates to:
  /// **'Aberdeen'**
  String get cityAberdeen;

  /// No description provided for @cityBath.
  ///
  /// In en, this message translates to:
  /// **'Bath'**
  String get cityBath;

  /// No description provided for @cityDundee.
  ///
  /// In en, this message translates to:
  /// **'Dundee'**
  String get cityDundee;

  /// No description provided for @cityReading.
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get cityReading;

  /// No description provided for @cityStAndrews.
  ///
  /// In en, this message translates to:
  /// **'St Andrews'**
  String get cityStAndrews;

  /// No description provided for @cityBelfast.
  ///
  /// In en, this message translates to:
  /// **'Belfast'**
  String get cityBelfast;

  /// No description provided for @cityBrighton.
  ///
  /// In en, this message translates to:
  /// **'Brighton'**
  String get cityBrighton;

  /// No description provided for @cityDurham.
  ///
  /// In en, this message translates to:
  /// **'Durham'**
  String get cityDurham;

  /// No description provided for @cityNorwich.
  ///
  /// In en, this message translates to:
  /// **'Norwich'**
  String get cityNorwich;

  /// No description provided for @citySwansea.
  ///
  /// In en, this message translates to:
  /// **'Swansea'**
  String get citySwansea;

  /// No description provided for @cityLoughborough.
  ///
  /// In en, this message translates to:
  /// **'Loughborough'**
  String get cityLoughborough;

  /// No description provided for @cityLancaster.
  ///
  /// In en, this message translates to:
  /// **'Lancaster'**
  String get cityLancaster;

  /// No description provided for @cityWarwick.
  ///
  /// In en, this message translates to:
  /// **'Warwick'**
  String get cityWarwick;

  /// No description provided for @cityCambridge.
  ///
  /// In en, this message translates to:
  /// **'Cambridge'**
  String get cityCambridge;

  /// No description provided for @cityOxford.
  ///
  /// In en, this message translates to:
  /// **'Oxford'**
  String get cityOxford;

  /// No description provided for @taskFilterCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get taskFilterCategory;

  /// No description provided for @taskFilterCity.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get taskFilterCity;

  /// No description provided for @taskFilterSelectCategory.
  ///
  /// In en, this message translates to:
  /// **'Select Category'**
  String get taskFilterSelectCategory;

  /// No description provided for @taskFilterSelectCity.
  ///
  /// In en, this message translates to:
  /// **'Select City'**
  String get taskFilterSelectCity;

  /// No description provided for @createTaskBasicInfo.
  ///
  /// In en, this message translates to:
  /// **'Basic Information'**
  String get createTaskBasicInfo;

  /// No description provided for @createTaskRewardLocation.
  ///
  /// In en, this message translates to:
  /// **'Reward & Location'**
  String get createTaskRewardLocation;

  /// No description provided for @createTaskCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get createTaskCurrency;

  /// No description provided for @createTaskTaskType.
  ///
  /// In en, this message translates to:
  /// **'Task Type'**
  String get createTaskTaskType;

  /// No description provided for @createTaskImages.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get createTaskImages;

  /// No description provided for @createTaskAddImages.
  ///
  /// In en, this message translates to:
  /// **'Add Images'**
  String get createTaskAddImages;

  /// No description provided for @createTaskFillAllRequired.
  ///
  /// In en, this message translates to:
  /// **'Please fill in all required fields'**
  String get createTaskFillAllRequired;

  /// No description provided for @createTaskImageUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Some images failed to upload, please try again'**
  String get createTaskImageUploadFailed;

  /// No description provided for @createTaskStudentVerificationRequired.
  ///
  /// In en, this message translates to:
  /// **'Only verified students can post campus life tasks'**
  String get createTaskStudentVerificationRequired;

  /// No description provided for @taskExpertBecomeExpert.
  ///
  /// In en, this message translates to:
  /// **'Become Expert'**
  String get taskExpertBecomeExpert;

  /// No description provided for @taskExpertBecomeExpertTitle.
  ///
  /// In en, this message translates to:
  /// **'Become a Task Expert'**
  String get taskExpertBecomeExpertTitle;

  /// No description provided for @taskExpertShowcaseSkills.
  ///
  /// In en, this message translates to:
  /// **'Showcase your professional skills and get more task opportunities'**
  String get taskExpertShowcaseSkills;

  /// No description provided for @taskExpertBenefits.
  ///
  /// In en, this message translates to:
  /// **'Benefits of Becoming an Expert'**
  String get taskExpertBenefits;

  /// No description provided for @taskExpertHowToApply.
  ///
  /// In en, this message translates to:
  /// **'How to Apply?'**
  String get taskExpertHowToApply;

  /// No description provided for @taskExpertApplyNow.
  ///
  /// In en, this message translates to:
  /// **'Apply Now'**
  String get taskExpertApplyNow;

  /// No description provided for @taskExpertLoginToApply.
  ///
  /// In en, this message translates to:
  /// **'Login to Apply'**
  String get taskExpertLoginToApply;

  /// No description provided for @taskExpertApplicationInfo.
  ///
  /// In en, this message translates to:
  /// **'Application Information'**
  String get taskExpertApplicationInfo;

  /// No description provided for @taskExpertApplicationHint.
  ///
  /// In en, this message translates to:
  /// **'Please introduce your professional skills, experience and advantages. This will help the platform better understand you.'**
  String get taskExpertApplicationHint;

  /// No description provided for @taskExpertSubmitApplication.
  ///
  /// In en, this message translates to:
  /// **'Submit Application'**
  String get taskExpertSubmitApplication;

  /// No description provided for @taskExpertApplicationSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Application Submitted'**
  String get taskExpertApplicationSubmitted;

  /// No description provided for @taskExpertNoIntro.
  ///
  /// In en, this message translates to:
  /// **'No Introduction'**
  String get taskExpertNoIntro;

  /// No description provided for @taskExpertServiceMenu.
  ///
  /// In en, this message translates to:
  /// **'Service Menu'**
  String get taskExpertServiceMenu;

  /// No description provided for @taskExpertOptionalTimeSlots.
  ///
  /// In en, this message translates to:
  /// **'Optional Time Slots'**
  String get taskExpertOptionalTimeSlots;

  /// No description provided for @taskExpertNoAvailableSlots.
  ///
  /// In en, this message translates to:
  /// **'No Available Time Slots'**
  String get taskExpertNoAvailableSlots;

  /// No description provided for @taskExpertApplyService.
  ///
  /// In en, this message translates to:
  /// **'Apply for Service'**
  String get taskExpertApplyService;

  /// No description provided for @taskExpertOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get taskExpertOptional;

  /// No description provided for @taskExpertFull.
  ///
  /// In en, this message translates to:
  /// **'Full'**
  String get taskExpertFull;

  /// No description provided for @taskExpertApplicationMessage.
  ///
  /// In en, this message translates to:
  /// **'Application Message'**
  String get taskExpertApplicationMessage;

  /// No description provided for @taskExpertNegotiatePrice.
  ///
  /// In en, this message translates to:
  /// **'Negotiate Price'**
  String get taskExpertNegotiatePrice;

  /// No description provided for @taskExpertExpertNegotiatePrice.
  ///
  /// In en, this message translates to:
  /// **'Task Expert Proposed Price Negotiation:'**
  String get taskExpertExpertNegotiatePrice;

  /// No description provided for @taskExpertViewTask.
  ///
  /// In en, this message translates to:
  /// **'View Task'**
  String get taskExpertViewTask;

  /// No description provided for @taskExpertTaskDetails.
  ///
  /// In en, this message translates to:
  /// **'Task Details: {param1}'**
  String taskExpertTaskDetails(String param1);

  /// No description provided for @taskExpertClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get taskExpertClear;

  /// No description provided for @taskExpertApplied.
  ///
  /// In en, this message translates to:
  /// **'Applied'**
  String get taskExpertApplied;

  /// No description provided for @taskExpertByAppointment.
  ///
  /// In en, this message translates to:
  /// **'By Appointment'**
  String get taskExpertByAppointment;

  /// No description provided for @forumNeedLogin.
  ///
  /// In en, this message translates to:
  /// **'Login Required'**
  String get forumNeedLogin;

  /// No description provided for @forumCommunityLoginMessage.
  ///
  /// In en, this message translates to:
  /// **'Community features are only available to logged-in users who have completed student verification'**
  String get forumCommunityLoginMessage;

  /// No description provided for @forumLoginNow.
  ///
  /// In en, this message translates to:
  /// **'Login Now'**
  String get forumLoginNow;

  /// No description provided for @forumNeedStudentVerification.
  ///
  /// In en, this message translates to:
  /// **'Student Verification Required'**
  String get forumNeedStudentVerification;

  /// No description provided for @forumVerificationPending.
  ///
  /// In en, this message translates to:
  /// **'Your student verification application is under review. Please wait patiently.'**
  String get forumVerificationPending;

  /// No description provided for @forumVerificationRejected.
  ///
  /// In en, this message translates to:
  /// **'Your student verification application was not approved. Please resubmit.'**
  String get forumVerificationRejected;

  /// No description provided for @forumCompleteVerification.
  ///
  /// In en, this message translates to:
  /// **'Please complete student verification to access community features'**
  String get forumCompleteVerification;

  /// No description provided for @forumCompleteVerificationMessage.
  ///
  /// In en, this message translates to:
  /// **'Please complete student verification to access community features'**
  String get forumCompleteVerificationMessage;

  /// No description provided for @forumGoVerify.
  ///
  /// In en, this message translates to:
  /// **'Go Verify'**
  String get forumGoVerify;

  /// No description provided for @forumReplies.
  ///
  /// In en, this message translates to:
  /// **'Replies ({param1})'**
  String forumReplies(String param1);

  /// No description provided for @forumLoadRepliesFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load replies: {param1}'**
  String forumLoadRepliesFailed(String param1);

  /// No description provided for @forumNoReplies.
  ///
  /// In en, this message translates to:
  /// **'No Comments'**
  String get forumNoReplies;

  /// No description provided for @forumPostReply.
  ///
  /// In en, this message translates to:
  /// **'Post Reply'**
  String get forumPostReply;

  /// No description provided for @forumSelectSection.
  ///
  /// In en, this message translates to:
  /// **'Select Section'**
  String get forumSelectSection;

  /// No description provided for @forumPleaseSelectSection.
  ///
  /// In en, this message translates to:
  /// **'Please Select Section'**
  String get forumPleaseSelectSection;

  /// No description provided for @forumPublish.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get forumPublish;

  /// No description provided for @forumSomeone.
  ///
  /// In en, this message translates to:
  /// **'Someone'**
  String get forumSomeone;

  /// No description provided for @forumNotificationNewReply.
  ///
  /// In en, this message translates to:
  /// **'New Reply'**
  String get forumNotificationNewReply;

  /// No description provided for @forumNotificationNewLike.
  ///
  /// In en, this message translates to:
  /// **'New Like'**
  String get forumNotificationNewLike;

  /// No description provided for @forumNotificationReplyPost.
  ///
  /// In en, this message translates to:
  /// **'{param1} replied to your post'**
  String forumNotificationReplyPost(String param1);

  /// No description provided for @forumNotificationReplyReply.
  ///
  /// In en, this message translates to:
  /// **'{param1} replied to your reply'**
  String forumNotificationReplyReply(String param1);

  /// No description provided for @forumNotificationLikePost.
  ///
  /// In en, this message translates to:
  /// **'{param1} liked your post'**
  String forumNotificationLikePost(String param1);

  /// No description provided for @forumNotificationLikeReply.
  ///
  /// In en, this message translates to:
  /// **'{param1} liked your reply'**
  String forumNotificationLikeReply(String param1);

  /// No description provided for @forumNotificationPinPost.
  ///
  /// In en, this message translates to:
  /// **'Post Pinned'**
  String get forumNotificationPinPost;

  /// No description provided for @forumNotificationPinPostContent.
  ///
  /// In en, this message translates to:
  /// **'Your post has been pinned by an administrator'**
  String get forumNotificationPinPostContent;

  /// No description provided for @forumNotificationFeaturePost.
  ///
  /// In en, this message translates to:
  /// **'Post Featured'**
  String get forumNotificationFeaturePost;

  /// No description provided for @forumNotificationFeaturePostContent.
  ///
  /// In en, this message translates to:
  /// **'Your post has been featured by an administrator'**
  String get forumNotificationFeaturePostContent;

  /// No description provided for @forumNotificationDefault.
  ///
  /// In en, this message translates to:
  /// **'Forum Notification'**
  String get forumNotificationDefault;

  /// No description provided for @forumNotificationDefaultContent.
  ///
  /// In en, this message translates to:
  /// **'You received a forum notification'**
  String get forumNotificationDefaultContent;

  /// No description provided for @infoConnectPlatform.
  ///
  /// In en, this message translates to:
  /// **'Connect You and Me Task Platform'**
  String get infoConnectPlatform;

  /// No description provided for @infoContactUs.
  ///
  /// In en, this message translates to:
  /// **'Contact Us'**
  String get infoContactUs;

  /// No description provided for @infoMemberBenefits.
  ///
  /// In en, this message translates to:
  /// **'Member Benefits'**
  String get infoMemberBenefits;

  /// No description provided for @infoFaq.
  ///
  /// In en, this message translates to:
  /// **'FAQ'**
  String get infoFaq;

  /// No description provided for @infoNeedHelp.
  ///
  /// In en, this message translates to:
  /// **'Need Help?'**
  String get infoNeedHelp;

  /// No description provided for @infoContactAdmin.
  ///
  /// In en, this message translates to:
  /// **'Contact administrator for more member information'**
  String get infoContactAdmin;

  /// No description provided for @infoContactService.
  ///
  /// In en, this message translates to:
  /// **'Contact Service'**
  String get infoContactService;

  /// No description provided for @infoTermsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get infoTermsOfService;

  /// No description provided for @infoPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get infoPrivacyPolicy;

  /// No description provided for @infoLastUpdated.
  ///
  /// In en, this message translates to:
  /// **'Last Updated: January 1, 2024'**
  String get infoLastUpdated;

  /// No description provided for @infoAboutUs.
  ///
  /// In en, this message translates to:
  /// **'About Us'**
  String get infoAboutUs;

  /// No description provided for @infoOurMission.
  ///
  /// In en, this message translates to:
  /// **'Our Mission'**
  String get infoOurMission;

  /// No description provided for @infoOurVision.
  ///
  /// In en, this message translates to:
  /// **'Our Vision'**
  String get infoOurVision;

  /// No description provided for @infoAboutUsContent.
  ///
  /// In en, this message translates to:
  /// **'Link²Ur is an innovative task posting and taking platform dedicated to connecting people who need help with those willing to provide help. We believe everyone has their own skills and time, and through the platform, these resources can be better utilized.'**
  String get infoAboutUsContent;

  /// No description provided for @infoOurMissionContent.
  ///
  /// In en, this message translates to:
  /// **'Make task posting and taking simple, efficient, and safe. We are committed to building a trusted community platform where everyone can find suitable tasks and help others.'**
  String get infoOurMissionContent;

  /// No description provided for @infoOurVisionContent.
  ///
  /// In en, this message translates to:
  /// **'Become the most popular task platform in the UK, connecting thousands of users, creating more value, and making the community closer.'**
  String get infoOurVisionContent;

  /// No description provided for @vipMember.
  ///
  /// In en, this message translates to:
  /// **'VIP Member'**
  String get vipMember;

  /// No description provided for @vipBecomeVip.
  ///
  /// In en, this message translates to:
  /// **'Become VIP Member'**
  String get vipBecomeVip;

  /// No description provided for @vipEnjoyBenefits.
  ///
  /// In en, this message translates to:
  /// **'Enjoy exclusive benefits and privileges'**
  String get vipEnjoyBenefits;

  /// No description provided for @vipUnlockPrivileges.
  ///
  /// In en, this message translates to:
  /// **'Unlock more privileges and services'**
  String get vipUnlockPrivileges;

  /// No description provided for @vipPriorityRecommendation.
  ///
  /// In en, this message translates to:
  /// **'Priority Recommendation'**
  String get vipPriorityRecommendation;

  /// No description provided for @vipPriorityRecommendationDesc.
  ///
  /// In en, this message translates to:
  /// **'Your tasks and applications will be prioritized, gaining more exposure'**
  String get vipPriorityRecommendationDesc;

  /// No description provided for @vipFeeDiscount.
  ///
  /// In en, this message translates to:
  /// **'Fee Discount'**
  String get vipFeeDiscount;

  /// No description provided for @vipFeeDiscountDesc.
  ///
  /// In en, this message translates to:
  /// **'Enjoy lower task posting fees, saving more costs'**
  String get vipFeeDiscountDesc;

  /// No description provided for @vipExclusiveBadge.
  ///
  /// In en, this message translates to:
  /// **'Exclusive Badge'**
  String get vipExclusiveBadge;

  /// No description provided for @vipExclusiveBadgeDesc.
  ///
  /// In en, this message translates to:
  /// **'Display exclusive VIP badge on profile to enhance your credibility'**
  String get vipExclusiveBadgeDesc;

  /// No description provided for @vipExclusiveActivity.
  ///
  /// In en, this message translates to:
  /// **'Exclusive Activities'**
  String get vipExclusiveActivity;

  /// No description provided for @vipExclusiveActivityDesc.
  ///
  /// In en, this message translates to:
  /// **'Participate in VIP exclusive activities and offers, get more rewards'**
  String get vipExclusiveActivityDesc;

  /// No description provided for @vipFaqHowToUpgrade.
  ///
  /// In en, this message translates to:
  /// **'How to upgrade membership?'**
  String get vipFaqHowToUpgrade;

  /// No description provided for @vipFaqHowToUpgradeAnswer.
  ///
  /// In en, this message translates to:
  /// **'The membership upgrade feature is currently under development. You can contact the administrator for manual upgrade, or wait for the automatic upgrade feature to be launched.'**
  String get vipFaqHowToUpgradeAnswer;

  /// No description provided for @vipFaqWhenEffective.
  ///
  /// In en, this message translates to:
  /// **'When do membership benefits take effect?'**
  String get vipFaqWhenEffective;

  /// No description provided for @vipFaqWhenEffectiveAnswer.
  ///
  /// In en, this message translates to:
  /// **'Membership benefits take effect immediately after upgrade, and you can immediately enjoy the corresponding privileged services.'**
  String get vipFaqWhenEffectiveAnswer;

  /// No description provided for @vipFaqCanCancel.
  ///
  /// In en, this message translates to:
  /// **'Can I cancel membership at any time?'**
  String get vipFaqCanCancel;

  /// No description provided for @vipFaqCanCancelAnswer.
  ///
  /// In en, this message translates to:
  /// **'Yes, you can contact the administrator to cancel membership service at any time. The cancellation will take effect in the next billing cycle.'**
  String get vipFaqCanCancelAnswer;

  /// No description provided for @vipComingSoon.
  ///
  /// In en, this message translates to:
  /// **'VIP feature coming soon, stay tuned!'**
  String get vipComingSoon;

  /// No description provided for @vipSelectPackage.
  ///
  /// In en, this message translates to:
  /// **'Choose the membership plan that suits you'**
  String get vipSelectPackage;

  /// No description provided for @vipNoProducts.
  ///
  /// In en, this message translates to:
  /// **'No VIP products available'**
  String get vipNoProducts;

  /// No description provided for @vipPerMonth.
  ///
  /// In en, this message translates to:
  /// **'/ month'**
  String get vipPerMonth;

  /// No description provided for @vipPerYear.
  ///
  /// In en, this message translates to:
  /// **'/ year'**
  String get vipPerYear;

  /// No description provided for @vipTryLaterContact.
  ///
  /// In en, this message translates to:
  /// **'Please try again later or contact support'**
  String get vipTryLaterContact;

  /// No description provided for @vipPleaseSelectPackage.
  ///
  /// In en, this message translates to:
  /// **'Please select a plan'**
  String get vipPleaseSelectPackage;

  /// No description provided for @vipBuyNow.
  ///
  /// In en, this message translates to:
  /// **'Purchase Now'**
  String get vipBuyNow;

  /// No description provided for @vipRestorePurchase.
  ///
  /// In en, this message translates to:
  /// **'Restore Purchase'**
  String get vipRestorePurchase;

  /// No description provided for @vipPurchaseInstructions.
  ///
  /// In en, this message translates to:
  /// **'Purchase Instructions'**
  String get vipPurchaseInstructions;

  /// No description provided for @vipSubscriptionAutoRenew.
  ///
  /// In en, this message translates to:
  /// **'• Subscription will auto-renew unless cancelled at least 24 hours before expiry'**
  String get vipSubscriptionAutoRenew;

  /// No description provided for @vipManageSubscription.
  ///
  /// In en, this message translates to:
  /// **'• Manage subscription in App Store account settings'**
  String get vipManageSubscription;

  /// No description provided for @vipPurchaseEffective.
  ///
  /// In en, this message translates to:
  /// **'• Benefits take effect immediately after purchase'**
  String get vipPurchaseEffective;

  /// No description provided for @vipPurchaseTitle.
  ///
  /// In en, this message translates to:
  /// **'Purchase VIP Membership'**
  String get vipPurchaseTitle;

  /// No description provided for @vipPurchaseSuccess.
  ///
  /// In en, this message translates to:
  /// **'Purchase Successful'**
  String get vipPurchaseSuccess;

  /// No description provided for @vipCongratulations.
  ///
  /// In en, this message translates to:
  /// **'Congratulations on becoming a VIP member! Enjoy all VIP benefits.'**
  String get vipCongratulations;

  /// No description provided for @vipRestoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Restore failed: {param1}'**
  String vipRestoreFailed(String param1);

  /// No description provided for @vipPurchased.
  ///
  /// In en, this message translates to:
  /// **'Purchased'**
  String get vipPurchased;

  /// No description provided for @vipAlreadyVip.
  ///
  /// In en, this message translates to:
  /// **'You are already a VIP member'**
  String get vipAlreadyVip;

  /// No description provided for @vipThankYou.
  ///
  /// In en, this message translates to:
  /// **'Thank you for your support. Enjoy all VIP benefits.'**
  String get vipThankYou;

  /// No description provided for @vipExpiryTime.
  ///
  /// In en, this message translates to:
  /// **'Expires: {param1}'**
  String vipExpiryTime(String param1);

  /// No description provided for @vipWillAutoRenew.
  ///
  /// In en, this message translates to:
  /// **'Will auto-renew'**
  String get vipWillAutoRenew;

  /// No description provided for @vipAutoRenewCancelled.
  ///
  /// In en, this message translates to:
  /// **'Auto-renew cancelled'**
  String get vipAutoRenewCancelled;

  /// No description provided for @vipFaqHowToUpgradeSteps.
  ///
  /// In en, this message translates to:
  /// **'Tap the \'Upgrade to VIP\' button on the VIP membership page and choose a suitable plan to purchase.'**
  String get vipFaqHowToUpgradeSteps;

  /// No description provided for @serviceNoImages.
  ///
  /// In en, this message translates to:
  /// **'No images'**
  String get serviceNoImages;

  /// No description provided for @serviceDetail.
  ///
  /// In en, this message translates to:
  /// **'Service Details'**
  String get serviceDetail;

  /// No description provided for @serviceNoDescription.
  ///
  /// In en, this message translates to:
  /// **'No detailed description'**
  String get serviceNoDescription;

  /// No description provided for @serviceApplyMessage.
  ///
  /// In en, this message translates to:
  /// **'Application Message'**
  String get serviceApplyMessage;

  /// No description provided for @serviceExpectedPrice.
  ///
  /// In en, this message translates to:
  /// **'Expected price'**
  String get serviceExpectedPrice;

  /// No description provided for @serviceFlexibleTime.
  ///
  /// In en, this message translates to:
  /// **'Flexible time'**
  String get serviceFlexibleTime;

  /// No description provided for @serviceExpectedDate.
  ///
  /// In en, this message translates to:
  /// **'Expected completion date'**
  String get serviceExpectedDate;

  /// No description provided for @serviceSelectDate.
  ///
  /// In en, this message translates to:
  /// **'Select date'**
  String get serviceSelectDate;

  /// No description provided for @serviceApplyTitle.
  ///
  /// In en, this message translates to:
  /// **'Apply for Service'**
  String get serviceApplyTitle;

  /// No description provided for @offlineMode.
  ///
  /// In en, this message translates to:
  /// **'Offline mode'**
  String get offlineMode;

  /// No description provided for @offlinePendingSync.
  ///
  /// In en, this message translates to:
  /// **'({param1} pending sync)'**
  String offlinePendingSync(int param1);

  /// No description provided for @networkOffline.
  ///
  /// In en, this message translates to:
  /// **'Network disconnected'**
  String get networkOffline;

  /// No description provided for @networkDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Network disconnected'**
  String get networkDisconnected;

  /// No description provided for @networkCheckSettings.
  ///
  /// In en, this message translates to:
  /// **'Please check your network settings'**
  String get networkCheckSettings;

  /// No description provided for @networkRestored.
  ///
  /// In en, this message translates to:
  /// **'Network restored'**
  String get networkRestored;

  /// No description provided for @networkConnectedWifi.
  ///
  /// In en, this message translates to:
  /// **'Connected to Wi-Fi'**
  String get networkConnectedWifi;

  /// No description provided for @networkConnectedCellular.
  ///
  /// In en, this message translates to:
  /// **'Connected to cellular'**
  String get networkConnectedCellular;

  /// No description provided for @networkConnectedEthernet.
  ///
  /// In en, this message translates to:
  /// **'Connected to Ethernet'**
  String get networkConnectedEthernet;

  /// No description provided for @networkConnected.
  ///
  /// In en, this message translates to:
  /// **'Network connected'**
  String get networkConnected;

  /// No description provided for @notificationExpiresSeconds.
  ///
  /// In en, this message translates to:
  /// **'Expires in {param1} seconds'**
  String notificationExpiresSeconds(double param1);

  /// No description provided for @notificationExpiresMinutes.
  ///
  /// In en, this message translates to:
  /// **'Expires in {param1} minutes'**
  String notificationExpiresMinutes(int param1);

  /// No description provided for @notificationExpiresHours.
  ///
  /// In en, this message translates to:
  /// **'Expires in {param1} hours'**
  String notificationExpiresHours(int param1);

  /// No description provided for @notificationViewFull.
  ///
  /// In en, this message translates to:
  /// **'View full'**
  String get notificationViewFull;

  /// No description provided for @notificationExpiryTime.
  ///
  /// In en, this message translates to:
  /// **'Expiry: {param1}'**
  String notificationExpiryTime(String param1);

  /// No description provided for @notificationUnread.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get notificationUnread;

  /// No description provided for @notificationContent.
  ///
  /// In en, this message translates to:
  /// **'Notification content'**
  String get notificationContent;

  /// No description provided for @notificationDetail.
  ///
  /// In en, this message translates to:
  /// **'Notification Detail'**
  String get notificationDetail;

  /// No description provided for @notificationGetNegotiationFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load negotiation info. Please refresh and try again.'**
  String get notificationGetNegotiationFailed;

  /// No description provided for @translationFailed.
  ///
  /// In en, this message translates to:
  /// **'Translation Failed'**
  String get translationFailed;

  /// No description provided for @translationRetryMessage.
  ///
  /// In en, this message translates to:
  /// **'Unable to translate this message. Please check your network and try again.'**
  String get translationRetryMessage;

  /// No description provided for @taskDetailCollapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get taskDetailCollapse;

  /// No description provided for @taskDetailExpandAll.
  ///
  /// In en, this message translates to:
  /// **'Expand all'**
  String get taskDetailExpandAll;

  /// No description provided for @taskDetailCompletedCount.
  ///
  /// In en, this message translates to:
  /// **'{param1} completed'**
  String taskDetailCompletedCount(int param1);

  /// No description provided for @taskDetailExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get taskDetailExpired;

  /// No description provided for @taskDetailRemainingMinutes.
  ///
  /// In en, this message translates to:
  /// **'{param1} min remaining'**
  String taskDetailRemainingMinutes(int param1);

  /// No description provided for @taskDetailRemainingHours.
  ///
  /// In en, this message translates to:
  /// **'{param1} hrs remaining'**
  String taskDetailRemainingHours(int param1);

  /// No description provided for @taskDetailRemainingDays.
  ///
  /// In en, this message translates to:
  /// **'{param1} days remaining'**
  String taskDetailRemainingDays(int param1);

  /// No description provided for @walletQuickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get walletQuickActions;

  /// No description provided for @walletRecentTransactions.
  ///
  /// In en, this message translates to:
  /// **'Recent Transactions'**
  String get walletRecentTransactions;

  /// No description provided for @walletBalance.
  ///
  /// In en, this message translates to:
  /// **'Wallet Balance'**
  String get walletBalance;

  /// No description provided for @walletMyWallet.
  ///
  /// In en, this message translates to:
  /// **'My Wallet'**
  String get walletMyWallet;

  /// No description provided for @walletPaymentRecordsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View all payment records'**
  String get walletPaymentRecordsSubtitle;

  /// No description provided for @walletPayoutManagementSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage your payouts'**
  String get walletPayoutManagementSubtitle;

  /// No description provided for @paymentLoadingForm.
  ///
  /// In en, this message translates to:
  /// **'Loading payment form...'**
  String get paymentLoadingForm;

  /// No description provided for @paymentPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing...'**
  String get paymentPreparing;

  /// No description provided for @paymentSuccess.
  ///
  /// In en, this message translates to:
  /// **'Payment Successful'**
  String get paymentSuccess;

  /// No description provided for @paymentSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Your payment has been successfully processed, the task will start soon.'**
  String get paymentSuccessMessage;

  /// No description provided for @paymentError.
  ///
  /// In en, this message translates to:
  /// **'Payment Error'**
  String get paymentError;

  /// No description provided for @paymentTaskInfo.
  ///
  /// In en, this message translates to:
  /// **'Task Information'**
  String get paymentTaskInfo;

  /// No description provided for @paymentTaskTitle.
  ///
  /// In en, this message translates to:
  /// **'Task Title'**
  String get paymentTaskTitle;

  /// No description provided for @paymentApplicant.
  ///
  /// In en, this message translates to:
  /// **'Applicant'**
  String get paymentApplicant;

  /// No description provided for @paymentTip.
  ///
  /// In en, this message translates to:
  /// **'Tip'**
  String get paymentTip;

  /// No description provided for @paymentConfirmPayment.
  ///
  /// In en, this message translates to:
  /// **'Confirm Payment'**
  String get paymentConfirmPayment;

  /// No description provided for @paymentPreparingPayment.
  ///
  /// In en, this message translates to:
  /// **'Preparing payment...'**
  String get paymentPreparingPayment;

  /// No description provided for @paymentPayment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get paymentPayment;

  /// No description provided for @paymentCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get paymentCancel;

  /// No description provided for @paymentRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get paymentRetry;

  /// No description provided for @paymentRetryPayment.
  ///
  /// In en, this message translates to:
  /// **'Retry Payment'**
  String get paymentRetryPayment;

  /// No description provided for @paymentCoupons.
  ///
  /// In en, this message translates to:
  /// **'Coupons'**
  String get paymentCoupons;

  /// No description provided for @paymentCouponDiscount.
  ///
  /// In en, this message translates to:
  /// **'Coupon Discount'**
  String get paymentCouponDiscount;

  /// No description provided for @paymentNoAvailableCoupons.
  ///
  /// In en, this message translates to:
  /// **'No Available Coupons'**
  String get paymentNoAvailableCoupons;

  /// No description provided for @paymentDoNotUseCoupon.
  ///
  /// In en, this message translates to:
  /// **'Don\'t use coupon'**
  String get paymentDoNotUseCoupon;

  /// No description provided for @paymentTimeoutOrRefreshHint.
  ///
  /// In en, this message translates to:
  /// **'If you have already paid, close this page and refresh; otherwise please try again'**
  String get paymentTimeoutOrRefreshHint;

  /// No description provided for @paymentConfirmingDoNotRepeat.
  ///
  /// In en, this message translates to:
  /// **'Confirming payment. Please wait and do not pay again.'**
  String get paymentConfirmingDoNotRepeat;

  /// No description provided for @paymentWaitingConfirmHint.
  ///
  /// In en, this message translates to:
  /// **'If you have already paid, we will confirm automatically. Please wait (within about 5 minutes).'**
  String get paymentWaitingConfirmHint;

  /// No description provided for @paymentTotalAmount.
  ///
  /// In en, this message translates to:
  /// **'Total Amount'**
  String get paymentTotalAmount;

  /// No description provided for @paymentFinalPayment.
  ///
  /// In en, this message translates to:
  /// **'Final Payment'**
  String get paymentFinalPayment;

  /// No description provided for @paymentMixed.
  ///
  /// In en, this message translates to:
  /// **'Mixed'**
  String get paymentMixed;

  /// No description provided for @paymentSelectMethod.
  ///
  /// In en, this message translates to:
  /// **'Select Payment Method'**
  String get paymentSelectMethod;

  /// No description provided for @paymentPayWithApplePay.
  ///
  /// In en, this message translates to:
  /// **'Pay with Apple Pay'**
  String get paymentPayWithApplePay;

  /// No description provided for @paymentPayWithGooglePay.
  ///
  /// In en, this message translates to:
  /// **'Pay with Google Pay'**
  String get paymentPayWithGooglePay;

  /// No description provided for @paymentPayWithWechatPay.
  ///
  /// In en, this message translates to:
  /// **'Pay with WeChat Pay'**
  String get paymentPayWithWechatPay;

  /// No description provided for @paymentPayWithAlipay.
  ///
  /// In en, this message translates to:
  /// **'Pay with Alipay'**
  String get paymentPayWithAlipay;

  /// No description provided for @shareWechat.
  ///
  /// In en, this message translates to:
  /// **'WeChat'**
  String get shareWechat;

  /// No description provided for @shareWechatMoments.
  ///
  /// In en, this message translates to:
  /// **'Moments'**
  String get shareWechatMoments;

  /// No description provided for @shareQq.
  ///
  /// In en, this message translates to:
  /// **'QQ'**
  String get shareQq;

  /// No description provided for @shareQzone.
  ///
  /// In en, this message translates to:
  /// **'QQ Zone'**
  String get shareQzone;

  /// No description provided for @shareWeibo.
  ///
  /// In en, this message translates to:
  /// **'Weibo'**
  String get shareWeibo;

  /// No description provided for @shareSms.
  ///
  /// In en, this message translates to:
  /// **'SMS'**
  String get shareSms;

  /// No description provided for @shareCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy Link'**
  String get shareCopyLink;

  /// No description provided for @shareGenerateImage.
  ///
  /// In en, this message translates to:
  /// **'Generate Image'**
  String get shareGenerateImage;

  /// No description provided for @shareShareTo.
  ///
  /// In en, this message translates to:
  /// **'Share To'**
  String get shareShareTo;

  /// No description provided for @shareGeneratingImage.
  ///
  /// In en, this message translates to:
  /// **'Generating share image...'**
  String get shareGeneratingImage;

  /// No description provided for @shareImage.
  ///
  /// In en, this message translates to:
  /// **'Share Image'**
  String get shareImage;

  /// No description provided for @shareShareImage.
  ///
  /// In en, this message translates to:
  /// **'Share Image'**
  String get shareShareImage;

  /// No description provided for @shareSaveToPhotos.
  ///
  /// In en, this message translates to:
  /// **'Save to Photos'**
  String get shareSaveToPhotos;

  /// No description provided for @translationTranslating.
  ///
  /// In en, this message translates to:
  /// **'Translating...'**
  String get translationTranslating;

  /// No description provided for @translationTranslate.
  ///
  /// In en, this message translates to:
  /// **'Translate'**
  String get translationTranslate;

  /// No description provided for @translationShowTranslation.
  ///
  /// In en, this message translates to:
  /// **'Show Translation'**
  String get translationShowTranslation;

  /// No description provided for @translationShowOriginal.
  ///
  /// In en, this message translates to:
  /// **'Show Original'**
  String get translationShowOriginal;

  /// No description provided for @settingsNotifications.
  ///
  /// In en, this message translates to:
  /// **'Receive push notifications'**
  String get settingsNotifications;

  /// No description provided for @settingsAllowNotifications.
  ///
  /// In en, this message translates to:
  /// **'Allow Notifications'**
  String get settingsAllowNotifications;

  /// No description provided for @settingsSuccessSound.
  ///
  /// In en, this message translates to:
  /// **'Success Sound'**
  String get settingsSuccessSound;

  /// No description provided for @settingsSuccessSoundDescription.
  ///
  /// In en, this message translates to:
  /// **'Play a short sound when an action succeeds'**
  String get settingsSuccessSoundDescription;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsThemeMode.
  ///
  /// In en, this message translates to:
  /// **'Theme Mode'**
  String get settingsThemeMode;

  /// No description provided for @settingsMembership.
  ///
  /// In en, this message translates to:
  /// **'Membership'**
  String get settingsMembership;

  /// No description provided for @settingsVipMembership.
  ///
  /// In en, this message translates to:
  /// **'VIP Membership'**
  String get settingsVipMembership;

  /// No description provided for @settingsHelpSupport.
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get settingsHelpSupport;

  /// No description provided for @settingsFaq.
  ///
  /// In en, this message translates to:
  /// **'FAQ'**
  String get settingsFaq;

  /// No description provided for @settingsContactSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact Support'**
  String get settingsContactSupport;

  /// No description provided for @settingsLegal.
  ///
  /// In en, this message translates to:
  /// **'Legal Information'**
  String get settingsLegal;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsAppName.
  ///
  /// In en, this message translates to:
  /// **'App Name'**
  String get settingsAppName;

  /// No description provided for @settingsPaymentAccount.
  ///
  /// In en, this message translates to:
  /// **'Payment Account'**
  String get settingsPaymentAccount;

  /// No description provided for @settingsSetupPaymentAccount.
  ///
  /// In en, this message translates to:
  /// **'Setup Payment Account'**
  String get settingsSetupPaymentAccount;

  /// No description provided for @settingsAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccount;

  /// No description provided for @settingsUserId.
  ///
  /// In en, this message translates to:
  /// **'User ID'**
  String get settingsUserId;

  /// No description provided for @settingsDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get settingsDeleteAccount;

  /// No description provided for @settingsDeleteAccountMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete your account? This action cannot be undone. All your data will be permanently deleted.'**
  String get settingsDeleteAccountMessage;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @walletPayoutManagement.
  ///
  /// In en, this message translates to:
  /// **'Payout Management'**
  String get walletPayoutManagement;

  /// No description provided for @walletPaymentRecords.
  ///
  /// In en, this message translates to:
  /// **'Payment Records'**
  String get walletPaymentRecords;

  /// No description provided for @myTasksLoadingCompleted.
  ///
  /// In en, this message translates to:
  /// **'Loading completed tasks...'**
  String get myTasksLoadingCompleted;

  /// No description provided for @myTasksNetworkUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Network Unavailable'**
  String get myTasksNetworkUnavailable;

  /// No description provided for @myTasksCheckNetwork.
  ///
  /// In en, this message translates to:
  /// **'Please check your network connection and try again'**
  String get myTasksCheckNetwork;

  /// No description provided for @myTasksNoPendingApplications.
  ///
  /// In en, this message translates to:
  /// **'No Pending Applications'**
  String get myTasksNoPendingApplications;

  /// No description provided for @myTasksNoPendingApplicationsMessage.
  ///
  /// In en, this message translates to:
  /// **'You have no pending application records yet'**
  String get myTasksNoPendingApplicationsMessage;

  /// No description provided for @myTasksPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get myTasksPending;

  /// No description provided for @myTasksApplicationMessage.
  ///
  /// In en, this message translates to:
  /// **'Application Message'**
  String get myTasksApplicationMessage;

  /// No description provided for @myTasksViewDetails.
  ///
  /// In en, this message translates to:
  /// **'View Details'**
  String get myTasksViewDetails;

  /// No description provided for @myTasksTabAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get myTasksTabAll;

  /// No description provided for @myTasksTabPosted.
  ///
  /// In en, this message translates to:
  /// **'Posted'**
  String get myTasksTabPosted;

  /// No description provided for @myTasksTabTaken.
  ///
  /// In en, this message translates to:
  /// **'Taken'**
  String get myTasksTabTaken;

  /// No description provided for @myTasksTabPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get myTasksTabPending;

  /// No description provided for @myTasksTabInProgress.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get myTasksTabInProgress;

  /// No description provided for @myTasksTabCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get myTasksTabCompleted;

  /// No description provided for @myTasksTabCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get myTasksTabCancelled;

  /// No description provided for @myTasksEmptyAll.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t posted or accepted any tasks yet'**
  String get myTasksEmptyAll;

  /// No description provided for @myTasksEmptyPosted.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t posted any tasks yet'**
  String get myTasksEmptyPosted;

  /// No description provided for @myTasksEmptyTaken.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t accepted any tasks yet'**
  String get myTasksEmptyTaken;

  /// No description provided for @myTasksEmptyInProgress.
  ///
  /// In en, this message translates to:
  /// **'You have no in-progress tasks yet'**
  String get myTasksEmptyInProgress;

  /// No description provided for @myTasksEmptyPending.
  ///
  /// In en, this message translates to:
  /// **'You have no pending application records yet'**
  String get myTasksEmptyPending;

  /// No description provided for @myTasksEmptyCompleted.
  ///
  /// In en, this message translates to:
  /// **'You have no completed tasks yet'**
  String get myTasksEmptyCompleted;

  /// No description provided for @myTasksEmptyCancelled.
  ///
  /// In en, this message translates to:
  /// **'You have no cancelled tasks yet'**
  String get myTasksEmptyCancelled;

  /// No description provided for @myTasksRolePoster.
  ///
  /// In en, this message translates to:
  /// **'Poster'**
  String get myTasksRolePoster;

  /// No description provided for @myTasksRoleTaker.
  ///
  /// In en, this message translates to:
  /// **'Taker'**
  String get myTasksRoleTaker;

  /// No description provided for @myTasksRoleExpert.
  ///
  /// In en, this message translates to:
  /// **'Expert'**
  String get myTasksRoleExpert;

  /// No description provided for @myTasksRoleApplicant.
  ///
  /// In en, this message translates to:
  /// **'Applicant'**
  String get myTasksRoleApplicant;

  /// No description provided for @myTasksRoleParticipant.
  ///
  /// In en, this message translates to:
  /// **'Participant'**
  String get myTasksRoleParticipant;

  /// No description provided for @myTasksRoleUser.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get myTasksRoleUser;

  /// No description provided for @myTasksRoleOrganizer.
  ///
  /// In en, this message translates to:
  /// **'Organizer'**
  String get myTasksRoleOrganizer;

  /// No description provided for @myTasksRoleUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get myTasksRoleUnknown;

  /// No description provided for @taskSourceNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal Task'**
  String get taskSourceNormal;

  /// No description provided for @taskSourceFleaMarket.
  ///
  /// In en, this message translates to:
  /// **'Flea Market'**
  String get taskSourceFleaMarket;

  /// No description provided for @taskSourceExpertService.
  ///
  /// In en, this message translates to:
  /// **'Expert Service'**
  String get taskSourceExpertService;

  /// No description provided for @taskSourceExpertActivity.
  ///
  /// In en, this message translates to:
  /// **'Expert Activity'**
  String get taskSourceExpertActivity;

  /// No description provided for @taskStatusOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get taskStatusOpen;

  /// No description provided for @taskStatusInProgress.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get taskStatusInProgress;

  /// No description provided for @taskStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get taskStatusCompleted;

  /// No description provided for @taskStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get taskStatusCancelled;

  /// No description provided for @taskStatusPendingConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Pending Confirmation'**
  String get taskStatusPendingConfirmation;

  /// No description provided for @taskStatusPendingPayment.
  ///
  /// In en, this message translates to:
  /// **'Pending Payment'**
  String get taskStatusPendingPayment;

  /// No description provided for @taskStatusDisputed.
  ///
  /// In en, this message translates to:
  /// **'Disputed'**
  String get taskStatusDisputed;

  /// No description provided for @myPostsTitle.
  ///
  /// In en, this message translates to:
  /// **'My Posts'**
  String get myPostsTitle;

  /// No description provided for @taskLocationAddress.
  ///
  /// In en, this message translates to:
  /// **'Task Address'**
  String get taskLocationAddress;

  /// No description provided for @taskLocationCoordinates.
  ///
  /// In en, this message translates to:
  /// **'Coordinates'**
  String get taskLocationCoordinates;

  /// No description provided for @taskLocationAppleMaps.
  ///
  /// In en, this message translates to:
  /// **'Apple Maps'**
  String get taskLocationAppleMaps;

  /// No description provided for @taskLocationMyLocation.
  ///
  /// In en, this message translates to:
  /// **'My Location'**
  String get taskLocationMyLocation;

  /// No description provided for @taskLocationLoadingAddress.
  ///
  /// In en, this message translates to:
  /// **'Loading address...'**
  String get taskLocationLoadingAddress;

  /// No description provided for @taskLocationDetailAddress.
  ///
  /// In en, this message translates to:
  /// **'Detail Address'**
  String get taskLocationDetailAddress;

  /// No description provided for @fleaMarketPublishItem.
  ///
  /// In en, this message translates to:
  /// **'List Item'**
  String get fleaMarketPublishItem;

  /// No description provided for @fleaMarketConfirmPurchase.
  ///
  /// In en, this message translates to:
  /// **'Confirm Purchase'**
  String get fleaMarketConfirmPurchase;

  /// No description provided for @fleaMarketBidPurchase.
  ///
  /// In en, this message translates to:
  /// **'Bid Purchase'**
  String get fleaMarketBidPurchase;

  /// No description provided for @fleaMarketPriceAndTransaction.
  ///
  /// In en, this message translates to:
  /// **'Price & Transaction'**
  String get fleaMarketPriceAndTransaction;

  /// No description provided for @fleaMarketAutoRemovalDays.
  ///
  /// In en, this message translates to:
  /// **'Auto removal in {param1} days'**
  String fleaMarketAutoRemovalDays(int param1);

  /// No description provided for @fleaMarketAutoRemovalSoon.
  ///
  /// In en, this message translates to:
  /// **'Item will be removed soon'**
  String get fleaMarketAutoRemovalSoon;

  /// No description provided for @fleaMarketLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get fleaMarketLoading;

  /// No description provided for @fleaMarketLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load item information'**
  String get fleaMarketLoadFailed;

  /// No description provided for @fleaMarketProductDetail.
  ///
  /// In en, this message translates to:
  /// **'Product Detail'**
  String get fleaMarketProductDetail;

  /// No description provided for @fleaMarketNoDescription.
  ///
  /// In en, this message translates to:
  /// **'Seller has not written anything~'**
  String get fleaMarketNoDescription;

  /// No description provided for @fleaMarketActiveSeller.
  ///
  /// In en, this message translates to:
  /// **'Active Seller'**
  String get fleaMarketActiveSeller;

  /// No description provided for @fleaMarketContactSeller.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get fleaMarketContactSeller;

  /// No description provided for @fleaMarketEditItem.
  ///
  /// In en, this message translates to:
  /// **'Edit Item'**
  String get fleaMarketEditItem;

  /// No description provided for @fleaMarketFavorite.
  ///
  /// In en, this message translates to:
  /// **'Favorite'**
  String get fleaMarketFavorite;

  /// No description provided for @fleaMarketNegotiate.
  ///
  /// In en, this message translates to:
  /// **'Negotiate'**
  String get fleaMarketNegotiate;

  /// No description provided for @fleaMarketBuyNow.
  ///
  /// In en, this message translates to:
  /// **'Buy Now'**
  String get fleaMarketBuyNow;

  /// No description provided for @fleaMarketYourBid.
  ///
  /// In en, this message translates to:
  /// **'Your Bid'**
  String get fleaMarketYourBid;

  /// No description provided for @fleaMarketMessageToSeller.
  ///
  /// In en, this message translates to:
  /// **'Message to Seller (Optional)'**
  String get fleaMarketMessageToSeller;

  /// No description provided for @fleaMarketMessagePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'e.g., Hope to meet in person, can you include shipping, etc...'**
  String get fleaMarketMessagePlaceholder;

  /// No description provided for @fleaMarketEnterAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter amount'**
  String get fleaMarketEnterAmount;

  /// No description provided for @fleaMarketNegotiateRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Negotiation Request Sent'**
  String get fleaMarketNegotiateRequestSent;

  /// No description provided for @fleaMarketNegotiateRequestSentMessage.
  ///
  /// In en, this message translates to:
  /// **'You have submitted a purchase request, please wait for the seller to process'**
  String get fleaMarketNegotiateRequestSentMessage;

  /// No description provided for @fleaMarketNegotiateRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send negotiation request. Please try again.'**
  String get fleaMarketNegotiateRequestFailed;

  /// No description provided for @fleaMarketNegotiatePriceInvalid.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid negotiation price.'**
  String get fleaMarketNegotiatePriceInvalid;

  /// No description provided for @fleaMarketNegotiatePriceTooHigh.
  ///
  /// In en, this message translates to:
  /// **'Negotiation price cannot be higher than the original price.'**
  String get fleaMarketNegotiatePriceTooHigh;

  /// No description provided for @fleaMarketNegotiatePriceTooLow.
  ///
  /// In en, this message translates to:
  /// **'Negotiation price must be greater than 0.'**
  String get fleaMarketNegotiatePriceTooLow;

  /// No description provided for @taskPreferencesTitle.
  ///
  /// In en, this message translates to:
  /// **'Task Preferences'**
  String get taskPreferencesTitle;

  /// No description provided for @taskPreferencesPreferredTypes.
  ///
  /// In en, this message translates to:
  /// **'Preferred Task Types'**
  String get taskPreferencesPreferredTypes;

  /// No description provided for @taskPreferencesPreferredTypesDescription.
  ///
  /// In en, this message translates to:
  /// **'Select task types you are interested in. The system will prioritize recommending these types of tasks'**
  String get taskPreferencesPreferredTypesDescription;

  /// No description provided for @taskPreferencesPreferredLocations.
  ///
  /// In en, this message translates to:
  /// **'Preferred Locations'**
  String get taskPreferencesPreferredLocations;

  /// No description provided for @taskPreferencesPreferredLocationsDescription.
  ///
  /// In en, this message translates to:
  /// **'Select the geographic locations where you want to receive tasks'**
  String get taskPreferencesPreferredLocationsDescription;

  /// No description provided for @taskPreferencesPreferredLevels.
  ///
  /// In en, this message translates to:
  /// **'Preferred Task Levels'**
  String get taskPreferencesPreferredLevels;

  /// No description provided for @taskPreferencesPreferredLevelsDescription.
  ///
  /// In en, this message translates to:
  /// **'Select task levels you are interested in'**
  String get taskPreferencesPreferredLevelsDescription;

  /// No description provided for @taskPreferencesMinDeadline.
  ///
  /// In en, this message translates to:
  /// **'Minimum Deadline'**
  String get taskPreferencesMinDeadline;

  /// No description provided for @taskPreferencesMinDeadlineDescription.
  ///
  /// In en, this message translates to:
  /// **'Set the minimum number of days required for task deadlines. The system will only recommend tasks that meet this condition'**
  String get taskPreferencesMinDeadlineDescription;

  /// No description provided for @taskPreferencesDays.
  ///
  /// In en, this message translates to:
  /// **'days'**
  String get taskPreferencesDays;

  /// No description provided for @taskPreferencesDaysRange.
  ///
  /// In en, this message translates to:
  /// **'(At least 1 day, at most 30 days)'**
  String get taskPreferencesDaysRange;

  /// No description provided for @taskPreferencesSave.
  ///
  /// In en, this message translates to:
  /// **'Save Preferences'**
  String get taskPreferencesSave;

  /// No description provided for @taskLocationSearchCity.
  ///
  /// In en, this message translates to:
  /// **'Search or enter city name'**
  String get taskLocationSearchCity;

  /// No description provided for @forumCreatePostTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Post'**
  String get forumCreatePostTitle;

  /// No description provided for @forumCreatePostBasicInfo.
  ///
  /// In en, this message translates to:
  /// **'Basic Information'**
  String get forumCreatePostBasicInfo;

  /// No description provided for @forumCreatePostPostTitle.
  ///
  /// In en, this message translates to:
  /// **'Post Title'**
  String get forumCreatePostPostTitle;

  /// No description provided for @forumCreatePostPostTitlePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Give your post an attractive title'**
  String get forumCreatePostPostTitlePlaceholder;

  /// No description provided for @forumCreatePostPostContent.
  ///
  /// In en, this message translates to:
  /// **'Post Content'**
  String get forumCreatePostPostContent;

  /// No description provided for @forumCreatePostContentPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Share your insights, experiences, or ask questions. Be friendly and help each other grow...'**
  String get forumCreatePostContentPlaceholder;

  /// No description provided for @forumCreatePostPublishing.
  ///
  /// In en, this message translates to:
  /// **'Publishing...'**
  String get forumCreatePostPublishing;

  /// No description provided for @forumCreatePostPublishNow.
  ///
  /// In en, this message translates to:
  /// **'Publish Now'**
  String get forumCreatePostPublishNow;

  /// No description provided for @forumCreatePostImages.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get forumCreatePostImages;

  /// No description provided for @forumCreatePostAddImage.
  ///
  /// In en, this message translates to:
  /// **'Add image'**
  String get forumCreatePostAddImage;

  /// No description provided for @fleaMarketCreatePublishing.
  ///
  /// In en, this message translates to:
  /// **'Publishing...'**
  String get fleaMarketCreatePublishing;

  /// No description provided for @fleaMarketCreatePublishNow.
  ///
  /// In en, this message translates to:
  /// **'Publish Item Now'**
  String get fleaMarketCreatePublishNow;

  /// No description provided for @fleaMarketCreateSearchLocation.
  ///
  /// In en, this message translates to:
  /// **'Search location or enter Online'**
  String get fleaMarketCreateSearchLocation;

  /// No description provided for @taskExpertTitle.
  ///
  /// In en, this message translates to:
  /// **'Task Experts'**
  String get taskExpertTitle;

  /// No description provided for @taskExpertWhatIs.
  ///
  /// In en, this message translates to:
  /// **'What are Task Experts?'**
  String get taskExpertWhatIs;

  /// No description provided for @taskExpertWhatIsContent.
  ///
  /// In en, this message translates to:
  /// **'Task Experts are platform-certified professional service providers with rich experience and good reputation. After becoming a Task Expert, your services will get more exposure and attract more customers.'**
  String get taskExpertWhatIsContent;

  /// No description provided for @taskExpertMoreExposure.
  ///
  /// In en, this message translates to:
  /// **'More Exposure'**
  String get taskExpertMoreExposure;

  /// No description provided for @taskExpertMoreExposureDesc.
  ///
  /// In en, this message translates to:
  /// **'Your services will be prioritized and get more user attention'**
  String get taskExpertMoreExposureDesc;

  /// No description provided for @taskExpertExclusiveBadge.
  ///
  /// In en, this message translates to:
  /// **'Exclusive Badge'**
  String get taskExpertExclusiveBadge;

  /// No description provided for @taskExpertExclusiveBadgeDesc.
  ///
  /// In en, this message translates to:
  /// **'Display expert certification badge to enhance your professional image'**
  String get taskExpertExclusiveBadgeDesc;

  /// No description provided for @taskExpertMoreOrders.
  ///
  /// In en, this message translates to:
  /// **'More Orders'**
  String get taskExpertMoreOrders;

  /// No description provided for @taskExpertMoreOrdersDesc.
  ///
  /// In en, this message translates to:
  /// **'Get more task applications and increase income opportunities'**
  String get taskExpertMoreOrdersDesc;

  /// No description provided for @taskExpertPlatformSupport.
  ///
  /// In en, this message translates to:
  /// **'Platform Support'**
  String get taskExpertPlatformSupport;

  /// No description provided for @taskExpertPlatformSupportDesc.
  ///
  /// In en, this message translates to:
  /// **'Enjoy professional support and resources provided by the platform'**
  String get taskExpertPlatformSupportDesc;

  /// No description provided for @taskExpertFillApplication.
  ///
  /// In en, this message translates to:
  /// **'Fill Application Information'**
  String get taskExpertFillApplication;

  /// No description provided for @taskExpertFillApplicationDesc.
  ///
  /// In en, this message translates to:
  /// **'Introduce your professional skills and experience'**
  String get taskExpertFillApplicationDesc;

  /// No description provided for @taskExpertSubmitReview.
  ///
  /// In en, this message translates to:
  /// **'Submit for Review'**
  String get taskExpertSubmitReview;

  /// No description provided for @taskExpertSubmitReviewDesc.
  ///
  /// In en, this message translates to:
  /// **'Platform will complete the review within 3-5 business days'**
  String get taskExpertSubmitReviewDesc;

  /// No description provided for @taskExpertStartService.
  ///
  /// In en, this message translates to:
  /// **'Start Service'**
  String get taskExpertStartService;

  /// No description provided for @taskExpertStartServiceDesc.
  ///
  /// In en, this message translates to:
  /// **'After approval, you can publish services and start accepting orders'**
  String get taskExpertStartServiceDesc;

  /// No description provided for @taskExpertApplyTitle.
  ///
  /// In en, this message translates to:
  /// **'Apply to Become Expert'**
  String get taskExpertApplyTitle;

  /// No description provided for @taskExpertApplicationSubmittedMessage.
  ///
  /// In en, this message translates to:
  /// **'Your application has been submitted. We will complete the review within 3-5 business days.'**
  String get taskExpertApplicationSubmittedMessage;

  /// No description provided for @taskExpertNoExperts.
  ///
  /// In en, this message translates to:
  /// **'No Task Experts'**
  String get taskExpertNoExperts;

  /// No description provided for @taskExpertNoExpertsMessage.
  ///
  /// In en, this message translates to:
  /// **'No task experts yet, stay tuned...'**
  String get taskExpertNoExpertsMessage;

  /// No description provided for @taskExpertNoExpertsSearchMessage.
  ///
  /// In en, this message translates to:
  /// **'No related experts found'**
  String get taskExpertNoExpertsSearchMessage;

  /// No description provided for @taskExpertSearchPrompt.
  ///
  /// In en, this message translates to:
  /// **'Search task experts'**
  String get taskExpertSearchPrompt;

  /// No description provided for @taskExpertNoFavorites.
  ///
  /// In en, this message translates to:
  /// **'No Favorites'**
  String get taskExpertNoFavorites;

  /// No description provided for @taskExpertNoActivities.
  ///
  /// In en, this message translates to:
  /// **'No Activities'**
  String get taskExpertNoActivities;

  /// No description provided for @taskExpertNoFavoritesMessage.
  ///
  /// In en, this message translates to:
  /// **'You have not favorited any activities'**
  String get taskExpertNoFavoritesMessage;

  /// No description provided for @taskExpertNoAppliedMessage.
  ///
  /// In en, this message translates to:
  /// **'You have not applied for any activities'**
  String get taskExpertNoAppliedMessage;

  /// No description provided for @taskExpertNoActivitiesMessage.
  ///
  /// In en, this message translates to:
  /// **'You have not applied or favorited any activities'**
  String get taskExpertNoActivitiesMessage;

  /// No description provided for @taskExpertRelatedActivitiesAvailable.
  ///
  /// In en, this message translates to:
  /// **'{count} related activities available'**
  String taskExpertRelatedActivitiesAvailable(int count);

  /// No description provided for @taskExpertRelatedActivitiesSection.
  ///
  /// In en, this message translates to:
  /// **'Expert\'s Related Activities'**
  String get taskExpertRelatedActivitiesSection;

  /// No description provided for @taskExpertExpertiseAreas.
  ///
  /// In en, this message translates to:
  /// **'Expertise Areas'**
  String get taskExpertExpertiseAreas;

  /// No description provided for @taskExpertFeaturedSkills.
  ///
  /// In en, this message translates to:
  /// **'Featured Skills'**
  String get taskExpertFeaturedSkills;

  /// No description provided for @taskExpertAchievements.
  ///
  /// In en, this message translates to:
  /// **'Achievements'**
  String get taskExpertAchievements;

  /// No description provided for @taskExpertResponseTime.
  ///
  /// In en, this message translates to:
  /// **'Response Time'**
  String get taskExpertResponseTime;

  /// No description provided for @taskExpertReviews.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get taskExpertReviews;

  /// No description provided for @taskExpertNoReviews.
  ///
  /// In en, this message translates to:
  /// **'No reviews yet'**
  String get taskExpertNoReviews;

  /// No description provided for @taskExpertReviewsCount.
  ///
  /// In en, this message translates to:
  /// **'{param1} reviews'**
  String taskExpertReviewsCount(int param1);

  /// No description provided for @taskExpertNoExpertiseAreas.
  ///
  /// In en, this message translates to:
  /// **'No expertise areas'**
  String get taskExpertNoExpertiseAreas;

  /// No description provided for @taskExpertNoFeaturedSkills.
  ///
  /// In en, this message translates to:
  /// **'No featured skills'**
  String get taskExpertNoFeaturedSkills;

  /// No description provided for @taskExpertNoAchievements.
  ///
  /// In en, this message translates to:
  /// **'No achievements'**
  String get taskExpertNoAchievements;

  /// No description provided for @leaderboardApplyTitle.
  ///
  /// In en, this message translates to:
  /// **'Apply for New Leaderboard'**
  String get leaderboardApplyTitle;

  /// No description provided for @leaderboardInfo.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard Information'**
  String get leaderboardInfo;

  /// No description provided for @leaderboardName.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard Name'**
  String get leaderboardName;

  /// No description provided for @leaderboardRegion.
  ///
  /// In en, this message translates to:
  /// **'Region'**
  String get leaderboardRegion;

  /// No description provided for @leaderboardDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get leaderboardDescription;

  /// No description provided for @leaderboardReason.
  ///
  /// In en, this message translates to:
  /// **'Application Reason'**
  String get leaderboardReason;

  /// No description provided for @leaderboardReasonTitle.
  ///
  /// In en, this message translates to:
  /// **'Why create this leaderboard?'**
  String get leaderboardReasonTitle;

  /// No description provided for @leaderboardReasonPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Explain to the administrator the necessity of creating this leaderboard, which helps speed up the review process...'**
  String get leaderboardReasonPlaceholder;

  /// No description provided for @leaderboardCoverImage.
  ///
  /// In en, this message translates to:
  /// **'Cover Image (Optional)'**
  String get leaderboardCoverImage;

  /// No description provided for @leaderboardAddCoverImage.
  ///
  /// In en, this message translates to:
  /// **'Add Cover Image'**
  String get leaderboardAddCoverImage;

  /// No description provided for @leaderboardOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get leaderboardOptional;

  /// No description provided for @leaderboardChangeImage.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get leaderboardChangeImage;

  /// No description provided for @leaderboardLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get leaderboardLoading;

  /// No description provided for @notificationNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationNotifications;

  /// No description provided for @notificationNoTaskChat.
  ///
  /// In en, this message translates to:
  /// **'No task chats'**
  String get notificationNoTaskChat;

  /// No description provided for @notificationNoTaskChatMessage.
  ///
  /// In en, this message translates to:
  /// **'No task-related chat records yet'**
  String get notificationNoTaskChatMessage;

  /// No description provided for @notificationNoMessages.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get notificationNoMessages;

  /// No description provided for @notificationStartConversation.
  ///
  /// In en, this message translates to:
  /// **'Start a conversation!'**
  String get notificationStartConversation;

  /// No description provided for @notificationNewMessage.
  ///
  /// In en, this message translates to:
  /// **'New messages'**
  String get notificationNewMessage;

  /// No description provided for @notificationSending.
  ///
  /// In en, this message translates to:
  /// **'Sending...'**
  String get notificationSending;

  /// No description provided for @notificationViewDetails.
  ///
  /// In en, this message translates to:
  /// **'View Details'**
  String get notificationViewDetails;

  /// No description provided for @notificationImage.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get notificationImage;

  /// No description provided for @notificationTaskDetail.
  ///
  /// In en, this message translates to:
  /// **'Task Detail'**
  String get notificationTaskDetail;

  /// No description provided for @notificationDetailAddress.
  ///
  /// In en, this message translates to:
  /// **'Detail Address'**
  String get notificationDetailAddress;

  /// No description provided for @notificationTaskEnded.
  ///
  /// In en, this message translates to:
  /// **'Task has ended'**
  String get notificationTaskEnded;

  /// No description provided for @notificationTaskCompletedCannotSend.
  ///
  /// In en, this message translates to:
  /// **'Task completed, cannot send messages'**
  String get notificationTaskCompletedCannotSend;

  /// No description provided for @notificationTaskCancelledCannotSend.
  ///
  /// In en, this message translates to:
  /// **'Task cancelled, cannot send messages'**
  String get notificationTaskCancelledCannotSend;

  /// No description provided for @notificationTaskPendingCannotSend.
  ///
  /// In en, this message translates to:
  /// **'Task pending confirmation, message sending paused'**
  String get notificationTaskPendingCannotSend;

  /// No description provided for @notificationSystemNotification.
  ///
  /// In en, this message translates to:
  /// **'System Notification'**
  String get notificationSystemNotification;

  /// No description provided for @notificationTitleTaskApplication.
  ///
  /// In en, this message translates to:
  /// **'New Task Application'**
  String get notificationTitleTaskApplication;

  /// No description provided for @notificationTitleApplicationAccepted.
  ///
  /// In en, this message translates to:
  /// **'Application Accepted - Payment Required'**
  String get notificationTitleApplicationAccepted;

  /// No description provided for @notificationTitleApplicationRejected.
  ///
  /// In en, this message translates to:
  /// **'Application Rejected'**
  String get notificationTitleApplicationRejected;

  /// No description provided for @notificationTitleApplicationWithdrawn.
  ///
  /// In en, this message translates to:
  /// **'Application Withdrawn'**
  String get notificationTitleApplicationWithdrawn;

  /// No description provided for @notificationTitleTaskCompleted.
  ///
  /// In en, this message translates to:
  /// **'Task Completed'**
  String get notificationTitleTaskCompleted;

  /// No description provided for @notificationTitleTaskConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Reward Issued'**
  String get notificationTitleTaskConfirmed;

  /// No description provided for @notificationTitleTaskCancelled.
  ///
  /// In en, this message translates to:
  /// **'Task Cancelled'**
  String get notificationTitleTaskCancelled;

  /// No description provided for @notificationTitleTaskAutoCancelled.
  ///
  /// In en, this message translates to:
  /// **'Task Auto-Cancelled'**
  String get notificationTitleTaskAutoCancelled;

  /// No description provided for @notificationTitleApplicationMessage.
  ///
  /// In en, this message translates to:
  /// **'New Message'**
  String get notificationTitleApplicationMessage;

  /// No description provided for @notificationTitleNegotiationOffer.
  ///
  /// In en, this message translates to:
  /// **'New Price Offer'**
  String get notificationTitleNegotiationOffer;

  /// No description provided for @notificationTitleNegotiationRejected.
  ///
  /// In en, this message translates to:
  /// **'Negotiation Rejected'**
  String get notificationTitleNegotiationRejected;

  /// No description provided for @notificationTitleTaskApproved.
  ///
  /// In en, this message translates to:
  /// **'Task Application Approved'**
  String get notificationTitleTaskApproved;

  /// No description provided for @notificationTitleTaskRewardPaid.
  ///
  /// In en, this message translates to:
  /// **'Task Reward Paid'**
  String get notificationTitleTaskRewardPaid;

  /// No description provided for @notificationTitleTaskApprovedWithPayment.
  ///
  /// In en, this message translates to:
  /// **'Task Application Approved - Payment Required'**
  String get notificationTitleTaskApprovedWithPayment;

  /// No description provided for @notificationTitleAnnouncement.
  ///
  /// In en, this message translates to:
  /// **'Announcement'**
  String get notificationTitleAnnouncement;

  /// No description provided for @notificationTitleCustomerService.
  ///
  /// In en, this message translates to:
  /// **'Customer Service'**
  String get notificationTitleCustomerService;

  /// No description provided for @notificationTitleUnknown.
  ///
  /// In en, this message translates to:
  /// **'Notification'**
  String get notificationTitleUnknown;

  /// No description provided for @notificationContentTaskApplication.
  ///
  /// In en, this message translates to:
  /// **'{applicant_name} applied for task「{task_title}」\\nApplication message: {application_message}\\nNegotiated price: {price_info}'**
  String notificationContentTaskApplication(String applicant_name,
      String task_title, String application_message, String price_info);

  /// No description provided for @notificationContentApplicationAccepted.
  ///
  /// In en, this message translates to:
  /// **'The applicant has accepted your negotiation offer for task「{task_title}」. Please complete the payment.{payment_expires_info}'**
  String notificationContentApplicationAccepted(
      String task_title, String payment_expires_info);

  /// No description provided for @notificationContentApplicationRejected.
  ///
  /// In en, this message translates to:
  /// **'Your task application has been rejected: {task_title}'**
  String notificationContentApplicationRejected(String task_title);

  /// No description provided for @notificationContentApplicationWithdrawn.
  ///
  /// In en, this message translates to:
  /// **'An applicant has withdrawn their application for task「{task_title}」'**
  String notificationContentApplicationWithdrawn(String task_title);

  /// No description provided for @notificationContentTaskCompleted.
  ///
  /// In en, this message translates to:
  /// **'{taker_name} has marked task「{task_title}」as completed'**
  String notificationContentTaskCompleted(String taker_name, String task_title);

  /// No description provided for @notificationContentTaskConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Task completed and confirmed! Reward for「{task_title}」has been issued'**
  String notificationContentTaskConfirmed(String task_title);

  /// No description provided for @notificationContentTaskCancelled.
  ///
  /// In en, this message translates to:
  /// **'Your task「{task_title}」has been cancelled'**
  String notificationContentTaskCancelled(String task_title);

  /// No description provided for @notificationContentTaskAutoCancelled.
  ///
  /// In en, this message translates to:
  /// **'Your task「{task_title}」has been automatically cancelled due to exceeding the deadline'**
  String notificationContentTaskAutoCancelled(String task_title);

  /// No description provided for @notificationContentApplicationMessage.
  ///
  /// In en, this message translates to:
  /// **'The publisher of task「{task_title}」sent you a message: {message}'**
  String notificationContentApplicationMessage(
      String task_title, String message);

  /// No description provided for @notificationContentNegotiationOffer.
  ///
  /// In en, this message translates to:
  /// **'The publisher of task「{task_title}」proposed a negotiation\nMessage: {message}\nNegotiated price: £{negotiated_price} {currency}'**
  String notificationContentNegotiationOffer(String task_title, String message,
      String negotiated_price, String currency);

  /// No description provided for @notificationContentNegotiationRejected.
  ///
  /// In en, this message translates to:
  /// **'The applicant has rejected your negotiation offer for task「{task_title}」'**
  String notificationContentNegotiationRejected(String task_title);

  /// No description provided for @notificationContentTaskApproved.
  ///
  /// In en, this message translates to:
  /// **'Your application for task「{task_title}」has been approved'**
  String notificationContentTaskApproved(String task_title);

  /// No description provided for @notificationContentTaskRewardPaid.
  ///
  /// In en, this message translates to:
  /// **'Reward for task「{task_title}」has been paid'**
  String notificationContentTaskRewardPaid(String task_title);

  /// No description provided for @notificationContentTaskApprovedWithPayment.
  ///
  /// In en, this message translates to:
  /// **'Your task application has been approved! Task: {task_title}{payment_expires_info}'**
  String notificationContentTaskApprovedWithPayment(
      String task_title, String payment_expires_info);

  /// No description provided for @notificationContentAnnouncement.
  ///
  /// In en, this message translates to:
  /// **'{message}'**
  String notificationContentAnnouncement(String message);

  /// No description provided for @notificationContentCustomerService.
  ///
  /// In en, this message translates to:
  /// **'{message}'**
  String notificationContentCustomerService(String message);

  /// No description provided for @notificationContentUnknown.
  ///
  /// In en, this message translates to:
  /// **'{message}'**
  String notificationContentUnknown(String message);

  /// No description provided for @notificationCustomerService.
  ///
  /// In en, this message translates to:
  /// **'Customer Service'**
  String get notificationCustomerService;

  /// No description provided for @notificationContactService.
  ///
  /// In en, this message translates to:
  /// **'Contact Service'**
  String get notificationContactService;

  /// No description provided for @notificationTaskChat.
  ///
  /// In en, this message translates to:
  /// **'Task Chat'**
  String get notificationTaskChat;

  /// No description provided for @notificationTaskChatList.
  ///
  /// In en, this message translates to:
  /// **'All Task Chat List'**
  String get notificationTaskChatList;

  /// No description provided for @notificationPoster.
  ///
  /// In en, this message translates to:
  /// **'Poster'**
  String get notificationPoster;

  /// No description provided for @notificationTaker.
  ///
  /// In en, this message translates to:
  /// **'Taker'**
  String get notificationTaker;

  /// No description provided for @notificationExpert.
  ///
  /// In en, this message translates to:
  /// **'Expert'**
  String get notificationExpert;

  /// No description provided for @notificationParticipant.
  ///
  /// In en, this message translates to:
  /// **'Participant'**
  String get notificationParticipant;

  /// No description provided for @notificationSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get notificationSystem;

  /// No description provided for @notificationSystemMessage.
  ///
  /// In en, this message translates to:
  /// **'System Message'**
  String get notificationSystemMessage;

  /// No description provided for @notificationTaskChats.
  ///
  /// In en, this message translates to:
  /// **'Task Chats'**
  String get notificationTaskChats;

  /// No description provided for @commonLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load More'**
  String get commonLoadMore;

  /// No description provided for @commonTagSeparator.
  ///
  /// In en, this message translates to:
  /// **', '**
  String get commonTagSeparator;

  /// No description provided for @commonCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get commonCopy;

  /// No description provided for @commonCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied: {param1}'**
  String commonCopied(String param1);

  /// No description provided for @commonTap.
  ///
  /// In en, this message translates to:
  /// **'Tap'**
  String get commonTap;

  /// No description provided for @commonLongPressToCopy.
  ///
  /// In en, this message translates to:
  /// **'Long press to copy'**
  String get commonLongPressToCopy;

  /// No description provided for @errorOperationFailed.
  ///
  /// In en, this message translates to:
  /// **'Operation Failed'**
  String get errorOperationFailed;

  /// No description provided for @onboardingSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkip;

  /// No description provided for @onboardingWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Link²Ur'**
  String get onboardingWelcomeTitle;

  /// No description provided for @onboardingWelcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Campus Mutual Aid Platform'**
  String get onboardingWelcomeSubtitle;

  /// No description provided for @onboardingWelcomeDescription.
  ///
  /// In en, this message translates to:
  /// **'Publish tasks, accept tasks, buy and sell second-hand goods, everything is in your hands'**
  String get onboardingWelcomeDescription;

  /// No description provided for @onboardingPublishTaskTitle.
  ///
  /// In en, this message translates to:
  /// **'Publish Tasks'**
  String get onboardingPublishTaskTitle;

  /// No description provided for @onboardingPublishTaskSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Easily find help'**
  String get onboardingPublishTaskSubtitle;

  /// No description provided for @onboardingPublishTaskDescription.
  ///
  /// In en, this message translates to:
  /// **'Need help? Publish a task and let capable users help you complete it'**
  String get onboardingPublishTaskDescription;

  /// No description provided for @onboardingAcceptTaskTitle.
  ///
  /// In en, this message translates to:
  /// **'Accept Tasks'**
  String get onboardingAcceptTaskTitle;

  /// No description provided for @onboardingAcceptTaskSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Earn extra income'**
  String get onboardingAcceptTaskSubtitle;

  /// No description provided for @onboardingAcceptTaskDescription.
  ///
  /// In en, this message translates to:
  /// **'Browse tasks, accept interesting tasks, and earn rewards after completing them'**
  String get onboardingAcceptTaskDescription;

  /// No description provided for @onboardingSecurePaymentTitle.
  ///
  /// In en, this message translates to:
  /// **'Secure Payment'**
  String get onboardingSecurePaymentTitle;

  /// No description provided for @onboardingSecurePaymentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Platform guarantees transaction security'**
  String get onboardingSecurePaymentSubtitle;

  /// No description provided for @onboardingSecurePaymentDescription.
  ///
  /// In en, this message translates to:
  /// **'Use Stripe secure payment, automatic transfer after task completion, protecting both parties\' rights'**
  String get onboardingSecurePaymentDescription;

  /// No description provided for @onboardingCommunityTitle.
  ///
  /// In en, this message translates to:
  /// **'Community Interaction'**
  String get onboardingCommunityTitle;

  /// No description provided for @onboardingCommunitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Connect your world'**
  String get onboardingCommunitySubtitle;

  /// No description provided for @onboardingCommunityDescription.
  ///
  /// In en, this message translates to:
  /// **'Participate in community discussions, view leaderboards, buy and sell second-hand goods, enrich your campus life'**
  String get onboardingCommunityDescription;

  /// No description provided for @onboardingPersonalizationTitle.
  ///
  /// In en, this message translates to:
  /// **'Personalization Settings'**
  String get onboardingPersonalizationTitle;

  /// No description provided for @onboardingPersonalizationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Help us recommend more suitable content for you'**
  String get onboardingPersonalizationSubtitle;

  /// No description provided for @onboardingPreferredCity.
  ///
  /// In en, this message translates to:
  /// **'Preferred City'**
  String get onboardingPreferredCity;

  /// No description provided for @onboardingUseCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Use Current Location'**
  String get onboardingUseCurrentLocation;

  /// No description provided for @onboardingPreferredTaskTypes.
  ///
  /// In en, this message translates to:
  /// **'Interested Task Types'**
  String get onboardingPreferredTaskTypes;

  /// No description provided for @onboardingPreferredTaskTypesOptional.
  ///
  /// In en, this message translates to:
  /// **'Interested Task Types (Optional)'**
  String get onboardingPreferredTaskTypesOptional;

  /// No description provided for @onboardingEnableNotifications.
  ///
  /// In en, this message translates to:
  /// **'Enable Notifications'**
  String get onboardingEnableNotifications;

  /// No description provided for @onboardingEnableNotificationsDescription.
  ///
  /// In en, this message translates to:
  /// **'Receive task status updates and message reminders in time'**
  String get onboardingEnableNotificationsDescription;

  /// No description provided for @onboardingGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get onboardingGetStarted;

  /// No description provided for @onboardingPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get onboardingPrevious;

  /// No description provided for @spotlightTask.
  ///
  /// In en, this message translates to:
  /// **'Task'**
  String get spotlightTask;

  /// No description provided for @spotlightTasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get spotlightTasks;

  /// No description provided for @spotlightExpert.
  ///
  /// In en, this message translates to:
  /// **'Task Expert'**
  String get spotlightExpert;

  /// No description provided for @spotlightQuickAction.
  ///
  /// In en, this message translates to:
  /// **'Quick Action'**
  String get spotlightQuickAction;

  /// No description provided for @shortcutsPublishTask.
  ///
  /// In en, this message translates to:
  /// **'Publish Task'**
  String get shortcutsPublishTask;

  /// No description provided for @shortcutsPublishTaskDescription.
  ///
  /// In en, this message translates to:
  /// **'Quickly publish a new task'**
  String get shortcutsPublishTaskDescription;

  /// No description provided for @shortcutsViewMyTasks.
  ///
  /// In en, this message translates to:
  /// **'View My Tasks'**
  String get shortcutsViewMyTasks;

  /// No description provided for @shortcutsViewMyTasksDescription.
  ///
  /// In en, this message translates to:
  /// **'View tasks I published and accepted'**
  String get shortcutsViewMyTasksDescription;

  /// No description provided for @shortcutsViewMessages.
  ///
  /// In en, this message translates to:
  /// **'View Messages'**
  String get shortcutsViewMessages;

  /// No description provided for @shortcutsViewMessagesDescription.
  ///
  /// In en, this message translates to:
  /// **'View unread messages and notifications'**
  String get shortcutsViewMessagesDescription;

  /// No description provided for @shortcutsSearchTasks.
  ///
  /// In en, this message translates to:
  /// **'Search Tasks'**
  String get shortcutsSearchTasks;

  /// No description provided for @shortcutsSearchTasksDescription.
  ///
  /// In en, this message translates to:
  /// **'Search for tasks'**
  String get shortcutsSearchTasksDescription;

  /// No description provided for @shortcutsViewFleaMarket.
  ///
  /// In en, this message translates to:
  /// **'View Flea Market'**
  String get shortcutsViewFleaMarket;

  /// No description provided for @shortcutsViewFleaMarketDescription.
  ///
  /// In en, this message translates to:
  /// **'Browse and publish second-hand goods'**
  String get shortcutsViewFleaMarketDescription;

  /// No description provided for @shortcutsViewForum.
  ///
  /// In en, this message translates to:
  /// **'View Forum'**
  String get shortcutsViewForum;

  /// No description provided for @shortcutsViewForumDescription.
  ///
  /// In en, this message translates to:
  /// **'Participate in community discussions'**
  String get shortcutsViewForumDescription;

  /// No description provided for @profileInProgress.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get profileInProgress;

  /// No description provided for @profileCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get profileCompleted;

  /// No description provided for @profileCreditScore.
  ///
  /// In en, this message translates to:
  /// **'Credit Score'**
  String get profileCreditScore;

  /// No description provided for @profileMyContent.
  ///
  /// In en, this message translates to:
  /// **'My Content'**
  String get profileMyContent;

  /// No description provided for @profileSystemAndVerification.
  ///
  /// In en, this message translates to:
  /// **'System & Verification'**
  String get profileSystemAndVerification;

  /// No description provided for @profileMyTasksSubtitleText.
  ///
  /// In en, this message translates to:
  /// **'Manage tasks I published and accepted'**
  String get profileMyTasksSubtitleText;

  /// No description provided for @profileMyPostsSubtitleText.
  ///
  /// In en, this message translates to:
  /// **'Second-hand item transaction records'**
  String get profileMyPostsSubtitleText;

  /// No description provided for @profileMyForumPosts.
  ///
  /// In en, this message translates to:
  /// **'My Posts'**
  String get profileMyForumPosts;

  /// No description provided for @profileMyForumPostsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View discussions I posted in the forum'**
  String get profileMyForumPostsSubtitle;

  /// No description provided for @profileMyWalletSubtitleText.
  ///
  /// In en, this message translates to:
  /// **'Balance, recharge and withdrawal'**
  String get profileMyWalletSubtitleText;

  /// No description provided for @profilePointsCouponsSubtitleText.
  ///
  /// In en, this message translates to:
  /// **'Points details and coupons'**
  String get profilePointsCouponsSubtitleText;

  /// No description provided for @profileStudentVerificationSubtitleText.
  ///
  /// In en, this message translates to:
  /// **'Get student-exclusive verification badge'**
  String get profileStudentVerificationSubtitleText;

  /// No description provided for @profileActivitySubtitleText.
  ///
  /// In en, this message translates to:
  /// **'View offline activities I participated in'**
  String get profileActivitySubtitleText;

  /// No description provided for @profileTaskPreferences.
  ///
  /// In en, this message translates to:
  /// **'Task Preferences'**
  String get profileTaskPreferences;

  /// No description provided for @profileTaskPreferencesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Personalize recommended content'**
  String get profileTaskPreferencesSubtitle;

  /// No description provided for @profileMyApplicationsSubtitleText.
  ///
  /// In en, this message translates to:
  /// **'Expert/Service provider application status'**
  String get profileMyApplicationsSubtitleText;

  /// No description provided for @profileSettingsSubtitleText.
  ///
  /// In en, this message translates to:
  /// **'Profile, password and security'**
  String get profileSettingsSubtitleText;

  /// No description provided for @profilePaymentAccount.
  ///
  /// In en, this message translates to:
  /// **'Payout Account'**
  String get profilePaymentAccount;

  /// No description provided for @profilePaymentAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Set up payout account to receive task rewards'**
  String get profilePaymentAccountSubtitle;

  /// No description provided for @profileNoContactInfo.
  ///
  /// In en, this message translates to:
  /// **'No contact information'**
  String get profileNoContactInfo;

  /// No description provided for @profileUserProfile.
  ///
  /// In en, this message translates to:
  /// **'User Profile'**
  String get profileUserProfile;

  /// No description provided for @profilePostedTasks.
  ///
  /// In en, this message translates to:
  /// **'Posted'**
  String get profilePostedTasks;

  /// No description provided for @profileTakenTasks.
  ///
  /// In en, this message translates to:
  /// **'Taken Tasks'**
  String get profileTakenTasks;

  /// No description provided for @profileCompletedTasks.
  ///
  /// In en, this message translates to:
  /// **'Completed Tasks'**
  String get profileCompletedTasks;

  /// No description provided for @myItemsSelling.
  ///
  /// In en, this message translates to:
  /// **'Selling'**
  String get myItemsSelling;

  /// No description provided for @myItemsPurchased.
  ///
  /// In en, this message translates to:
  /// **'Purchased'**
  String get myItemsPurchased;

  /// No description provided for @myItemsFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get myItemsFavorites;

  /// No description provided for @myItemsSold.
  ///
  /// In en, this message translates to:
  /// **'Sold'**
  String get myItemsSold;

  /// No description provided for @myItemsEmptySelling.
  ///
  /// In en, this message translates to:
  /// **'No Items for Sale'**
  String get myItemsEmptySelling;

  /// No description provided for @myItemsEmptyPurchased.
  ///
  /// In en, this message translates to:
  /// **'No Purchase Records'**
  String get myItemsEmptyPurchased;

  /// No description provided for @myItemsEmptyFavorites.
  ///
  /// In en, this message translates to:
  /// **'No Favorites'**
  String get myItemsEmptyFavorites;

  /// No description provided for @myItemsEmptySold.
  ///
  /// In en, this message translates to:
  /// **'No Sold Items'**
  String get myItemsEmptySold;

  /// No description provided for @myItemsEmptySellingMessage.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t published any second-hand items yet'**
  String get myItemsEmptySellingMessage;

  /// No description provided for @myItemsEmptyPurchasedMessage.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t purchased any items yet'**
  String get myItemsEmptyPurchasedMessage;

  /// No description provided for @myItemsEmptyFavoritesMessage.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t favorited any items yet'**
  String get myItemsEmptyFavoritesMessage;

  /// No description provided for @myItemsEmptySoldMessage.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t successfully sold any items yet'**
  String get myItemsEmptySoldMessage;

  /// No description provided for @myItemsStatusSelling.
  ///
  /// In en, this message translates to:
  /// **'For Sale'**
  String get myItemsStatusSelling;

  /// No description provided for @myItemsStatusPurchased.
  ///
  /// In en, this message translates to:
  /// **'Purchased'**
  String get myItemsStatusPurchased;

  /// No description provided for @myItemsStatusSold.
  ///
  /// In en, this message translates to:
  /// **'Sold'**
  String get myItemsStatusSold;

  /// No description provided for @forumPinned.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get forumPinned;

  /// No description provided for @forumFeatured.
  ///
  /// In en, this message translates to:
  /// **'Featured'**
  String get forumFeatured;

  /// No description provided for @forumWriteReplyPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Write your reply...'**
  String get forumWriteReplyPlaceholder;

  /// No description provided for @forumViewThisPost.
  ///
  /// In en, this message translates to:
  /// **'Check out this post'**
  String get forumViewThisPost;

  /// No description provided for @forumBrowse.
  ///
  /// In en, this message translates to:
  /// **'Views'**
  String get forumBrowse;

  /// No description provided for @forumRepliesCount.
  ///
  /// In en, this message translates to:
  /// **'replies'**
  String get forumRepliesCount;

  /// No description provided for @fleaMarketStatusActive.
  ///
  /// In en, this message translates to:
  /// **'For Sale'**
  String get fleaMarketStatusActive;

  /// No description provided for @fleaMarketStatusDelisted.
  ///
  /// In en, this message translates to:
  /// **'Delisted'**
  String get fleaMarketStatusDelisted;

  /// No description provided for @fleaMarketRefreshing.
  ///
  /// In en, this message translates to:
  /// **'Refreshing...'**
  String get fleaMarketRefreshing;

  /// No description provided for @fleaMarketRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get fleaMarketRefresh;

  /// No description provided for @fleaMarketConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get fleaMarketConfirm;

  /// No description provided for @fleaMarketSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get fleaMarketSubmit;

  /// No description provided for @fleaMarketViewItem.
  ///
  /// In en, this message translates to:
  /// **'View this item'**
  String get fleaMarketViewItem;

  /// No description provided for @fleaMarketSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get fleaMarketSaving;

  /// No description provided for @fleaMarketSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get fleaMarketSaveChanges;

  /// No description provided for @fleaMarketEditItemTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Item'**
  String get fleaMarketEditItemTitle;

  /// No description provided for @fleaMarketCategoryElectronics.
  ///
  /// In en, this message translates to:
  /// **'Electronics'**
  String get fleaMarketCategoryElectronics;

  /// No description provided for @fleaMarketCategoryClothing.
  ///
  /// In en, this message translates to:
  /// **'Clothing & Bags'**
  String get fleaMarketCategoryClothing;

  /// No description provided for @fleaMarketCategoryFurniture.
  ///
  /// In en, this message translates to:
  /// **'Furniture & Appliances'**
  String get fleaMarketCategoryFurniture;

  /// No description provided for @fleaMarketCategoryBooks.
  ///
  /// In en, this message translates to:
  /// **'Books & Textbooks'**
  String get fleaMarketCategoryBooks;

  /// No description provided for @fleaMarketCategorySports.
  ///
  /// In en, this message translates to:
  /// **'Sports & Outdoor'**
  String get fleaMarketCategorySports;

  /// No description provided for @fleaMarketCategoryBeauty.
  ///
  /// In en, this message translates to:
  /// **'Beauty & Skincare'**
  String get fleaMarketCategoryBeauty;

  /// No description provided for @fleaMarketCategoryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get fleaMarketCategoryOther;

  /// No description provided for @fleaMarketPartialUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Some images failed to upload, please try again'**
  String get fleaMarketPartialUploadFailed;

  /// No description provided for @fleaMarketUploadTimeout.
  ///
  /// In en, this message translates to:
  /// **'Image upload timed out, please try again'**
  String get fleaMarketUploadTimeout;

  /// No description provided for @fleaMarketPickImageBusy.
  ///
  /// In en, this message translates to:
  /// **'Image picker is busy, please try again later'**
  String get fleaMarketPickImageBusy;

  /// No description provided for @fleaMarketFillRequiredFields.
  ///
  /// In en, this message translates to:
  /// **'Please fill in all required fields'**
  String get fleaMarketFillRequiredFields;

  /// No description provided for @fleaMarketPurchaseRequestsCount.
  ///
  /// In en, this message translates to:
  /// **'Purchase Requests ({param1})'**
  String fleaMarketPurchaseRequestsCount(int param1);

  /// No description provided for @fleaMarketNoPurchaseRequests.
  ///
  /// In en, this message translates to:
  /// **'No Purchase Requests'**
  String get fleaMarketNoPurchaseRequests;

  /// No description provided for @fleaMarketWaitingSellerConfirm.
  ///
  /// In en, this message translates to:
  /// **'Waiting for seller confirmation'**
  String get fleaMarketWaitingSellerConfirm;

  /// No description provided for @fleaMarketNegotiateAmountFormat.
  ///
  /// In en, this message translates to:
  /// **'Negotiated price: £{param1}'**
  String fleaMarketNegotiateAmountFormat(double param1);

  /// No description provided for @fleaMarketContinuePayment.
  ///
  /// In en, this message translates to:
  /// **'Continue Payment'**
  String get fleaMarketContinuePayment;

  /// No description provided for @fleaMarketPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing...'**
  String get fleaMarketPreparing;

  /// No description provided for @fleaMarketSendingNegotiateRequest.
  ///
  /// In en, this message translates to:
  /// **'Sending negotiation request...'**
  String get fleaMarketSendingNegotiateRequest;

  /// No description provided for @fleaMarketProcessingPurchase.
  ///
  /// In en, this message translates to:
  /// **'Processing purchase...'**
  String get fleaMarketProcessingPurchase;

  /// No description provided for @fleaMarketNegotiateAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Negotiated price:'**
  String get fleaMarketNegotiateAmountLabel;

  /// No description provided for @fleaMarketSellerNegotiateLabel.
  ///
  /// In en, this message translates to:
  /// **'Seller counter offer:'**
  String get fleaMarketSellerNegotiateLabel;

  /// No description provided for @fleaMarketRejectPurchaseConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Reject Purchase Request'**
  String get fleaMarketRejectPurchaseConfirmTitle;

  /// No description provided for @fleaMarketRejectPurchaseConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to reject this purchase request?'**
  String get fleaMarketRejectPurchaseConfirmMessage;

  /// No description provided for @fleaMarketRequestStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get fleaMarketRequestStatusPending;

  /// No description provided for @fleaMarketRequestStatusSellerNegotiating.
  ///
  /// In en, this message translates to:
  /// **'Seller Negotiating'**
  String get fleaMarketRequestStatusSellerNegotiating;

  /// No description provided for @fleaMarketRequestStatusAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get fleaMarketRequestStatusAccepted;

  /// No description provided for @fleaMarketRequestStatusRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get fleaMarketRequestStatusRejected;

  /// No description provided for @fleaMarketAcceptCounterOffer.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get fleaMarketAcceptCounterOffer;

  /// No description provided for @fleaMarketRejectCounterOffer.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get fleaMarketRejectCounterOffer;

  /// No description provided for @fleaMarketCounterOfferReceived.
  ///
  /// In en, this message translates to:
  /// **'Seller counter-offered £{price}'**
  String fleaMarketCounterOfferReceived(String price);

  /// No description provided for @fleaMarketAcceptCounterOfferConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Accept Counter Offer'**
  String get fleaMarketAcceptCounterOfferConfirmTitle;

  /// No description provided for @fleaMarketAcceptCounterOfferConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to accept the seller\'s counter offer of £{price}?'**
  String fleaMarketAcceptCounterOfferConfirmMessage(String price);

  /// No description provided for @fleaMarketRejectCounterOfferConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Decline Counter Offer'**
  String get fleaMarketRejectCounterOfferConfirmTitle;

  /// No description provided for @fleaMarketRejectCounterOfferConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to decline the seller\'s counter offer?'**
  String get fleaMarketRejectCounterOfferConfirmMessage;

  /// No description provided for @fleaMarketCounterOfferAccepted.
  ///
  /// In en, this message translates to:
  /// **'Counter offer accepted'**
  String get fleaMarketCounterOfferAccepted;

  /// No description provided for @fleaMarketCounterOfferRejected.
  ///
  /// In en, this message translates to:
  /// **'Counter offer declined'**
  String get fleaMarketCounterOfferRejected;

  /// No description provided for @applePayNotSupported.
  ///
  /// In en, this message translates to:
  /// **'Your device does not support Apple Pay'**
  String get applePayNotSupported;

  /// No description provided for @applePayUseOtherMethod.
  ///
  /// In en, this message translates to:
  /// **'Please use another payment method'**
  String get applePayUseOtherMethod;

  /// No description provided for @applePayTitle.
  ///
  /// In en, this message translates to:
  /// **'Apple Pay'**
  String get applePayTitle;

  /// No description provided for @applePayNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Apple Pay is not configured'**
  String get applePayNotConfigured;

  /// No description provided for @applePayPaymentInfoNotReady.
  ///
  /// In en, this message translates to:
  /// **'Payment info not ready'**
  String get applePayPaymentInfoNotReady;

  /// No description provided for @applePayTaskPaymentFallback.
  ///
  /// In en, this message translates to:
  /// **'Link²Ur Task Payment'**
  String get applePayTaskPaymentFallback;

  /// No description provided for @applePayUnableToCreateForm.
  ///
  /// In en, this message translates to:
  /// **'Unable to create Apple Pay form'**
  String get applePayUnableToCreateForm;

  /// No description provided for @applePayUnableToGetPaymentInfo.
  ///
  /// In en, this message translates to:
  /// **'Unable to get payment info'**
  String get applePayUnableToGetPaymentInfo;

  /// No description provided for @chatEvidenceFile.
  ///
  /// In en, this message translates to:
  /// **'Evidence file'**
  String get chatEvidenceFile;

  /// No description provided for @paymentUnknownError.
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get paymentUnknownError;

  /// No description provided for @paymentAmount.
  ///
  /// In en, this message translates to:
  /// **'Payment Amount'**
  String get paymentAmount;

  /// No description provided for @paymentSuccessCompleted.
  ///
  /// In en, this message translates to:
  /// **'Your payment has been successfully completed'**
  String get paymentSuccessCompleted;

  /// No description provided for @paymentFailed.
  ///
  /// In en, this message translates to:
  /// **'Payment Failed'**
  String get paymentFailed;

  /// No description provided for @wechatPayTitle.
  ///
  /// In en, this message translates to:
  /// **'WeChat Pay'**
  String get wechatPayTitle;

  /// No description provided for @wechatPayLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading payment page...'**
  String get wechatPayLoading;

  /// No description provided for @wechatPayLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Load Failed'**
  String get wechatPayLoadFailed;

  /// No description provided for @wechatPayCancelConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel Payment?'**
  String get wechatPayCancelConfirmTitle;

  /// No description provided for @wechatPayContinuePay.
  ///
  /// In en, this message translates to:
  /// **'Continue Payment'**
  String get wechatPayContinuePay;

  /// No description provided for @wechatPayCancelPay.
  ///
  /// In en, this message translates to:
  /// **'Cancel Payment'**
  String get wechatPayCancelPay;

  /// No description provided for @wechatPayCancelWarning.
  ///
  /// In en, this message translates to:
  /// **'You will need to initiate payment again if you cancel'**
  String get wechatPayCancelWarning;

  /// No description provided for @wechatPayInvalidLink.
  ///
  /// In en, this message translates to:
  /// **'Invalid payment link'**
  String get wechatPayInvalidLink;

  /// No description provided for @forumMyPosts.
  ///
  /// In en, this message translates to:
  /// **'My Posts'**
  String get forumMyPosts;

  /// No description provided for @forumMyPostsPosted.
  ///
  /// In en, this message translates to:
  /// **'Posted'**
  String get forumMyPostsPosted;

  /// No description provided for @forumMyPostsFavorited.
  ///
  /// In en, this message translates to:
  /// **'Favorited'**
  String get forumMyPostsFavorited;

  /// No description provided for @forumMyPostsLiked.
  ///
  /// In en, this message translates to:
  /// **'Liked'**
  String get forumMyPostsLiked;

  /// No description provided for @forumMyPostsEmptyPosted.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t posted any posts yet'**
  String get forumMyPostsEmptyPosted;

  /// No description provided for @forumMyPostsEmptyFavorited.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t favorited any posts yet'**
  String get forumMyPostsEmptyFavorited;

  /// No description provided for @forumMyPostsEmptyLiked.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t liked any posts yet'**
  String get forumMyPostsEmptyLiked;

  /// No description provided for @forumLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Load Failed'**
  String get forumLoadFailed;

  /// No description provided for @forumRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get forumRetry;

  /// No description provided for @forumNoCategories.
  ///
  /// In en, this message translates to:
  /// **'No Categories'**
  String get forumNoCategories;

  /// No description provided for @forumCategoriesLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading forum categories...'**
  String get forumCategoriesLoading;

  /// No description provided for @forumRequestNewCategory.
  ///
  /// In en, this message translates to:
  /// **'Request New Category'**
  String get forumRequestNewCategory;

  /// No description provided for @forumRequestSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Request Submitted'**
  String get forumRequestSubmitted;

  /// No description provided for @forumRequestSubmittedMessage.
  ///
  /// In en, this message translates to:
  /// **'Your request has been successfully submitted. The administrator will notify you of the result after review.'**
  String get forumRequestSubmittedMessage;

  /// No description provided for @forumRequestInstructions.
  ///
  /// In en, this message translates to:
  /// **'Request Instructions'**
  String get forumRequestInstructions;

  /// No description provided for @forumRequestInstructionsText.
  ///
  /// In en, this message translates to:
  /// **'Fill in the following information to request a new forum category. Your request will be reviewed by the administrator, and the category will be officially created after approval.'**
  String get forumRequestInstructionsText;

  /// No description provided for @forumCategoryName.
  ///
  /// In en, this message translates to:
  /// **'Category Name'**
  String get forumCategoryName;

  /// No description provided for @forumCategoryNamePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Please enter category name'**
  String get forumCategoryNamePlaceholder;

  /// No description provided for @forumCategoryDescription.
  ///
  /// In en, this message translates to:
  /// **'Category Description'**
  String get forumCategoryDescription;

  /// No description provided for @forumCategoryDescriptionPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Please briefly describe the purpose and discussion topics of this category'**
  String get forumCategoryDescriptionPlaceholder;

  /// No description provided for @forumCategoryIcon.
  ///
  /// In en, this message translates to:
  /// **'Category Icon (Optional)'**
  String get forumCategoryIcon;

  /// No description provided for @forumCategoryIconHint.
  ///
  /// In en, this message translates to:
  /// **'You can enter an emoji as the category icon, for example: 💬, 📚, 🎮, etc.'**
  String get forumCategoryIconHint;

  /// No description provided for @forumCategoryIconExample.
  ///
  /// In en, this message translates to:
  /// **'For example: 💬'**
  String get forumCategoryIconExample;

  /// No description provided for @forumCategoryIconEntered.
  ///
  /// In en, this message translates to:
  /// **'1 emoji entered'**
  String get forumCategoryIconEntered;

  /// No description provided for @forumSubmitRequest.
  ///
  /// In en, this message translates to:
  /// **'Submit Request'**
  String get forumSubmitRequest;

  /// No description provided for @forumMyRequests.
  ///
  /// In en, this message translates to:
  /// **'My Requests'**
  String get forumMyRequests;

  /// No description provided for @forumRequestStatusAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get forumRequestStatusAll;

  /// No description provided for @forumRequestStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get forumRequestStatusPending;

  /// No description provided for @forumRequestStatusApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get forumRequestStatusApproved;

  /// No description provided for @forumRequestStatusRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get forumRequestStatusRejected;

  /// No description provided for @forumNoRequests.
  ///
  /// In en, this message translates to:
  /// **'No Requests'**
  String get forumNoRequests;

  /// No description provided for @forumNoRequestsMessage.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t submitted any category requests yet.'**
  String get forumNoRequestsMessage;

  /// No description provided for @forumNoRequestsFiltered.
  ///
  /// In en, this message translates to:
  /// **'No requests found for this status.'**
  String get forumNoRequestsFiltered;

  /// No description provided for @forumReviewComment.
  ///
  /// In en, this message translates to:
  /// **'Review Comment'**
  String get forumReviewComment;

  /// No description provided for @forumReviewTime.
  ///
  /// In en, this message translates to:
  /// **'Review Time'**
  String get forumReviewTime;

  /// No description provided for @forumRequestTime.
  ///
  /// In en, this message translates to:
  /// **'Request Time'**
  String get forumRequestTime;

  /// No description provided for @forumRequestNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter category name'**
  String get forumRequestNameRequired;

  /// No description provided for @forumRequestNameTooLong.
  ///
  /// In en, this message translates to:
  /// **'Category name cannot exceed {param1} characters'**
  String forumRequestNameTooLong(int param1);

  /// No description provided for @forumRequestDescriptionTooLong.
  ///
  /// In en, this message translates to:
  /// **'Category description cannot exceed {param1} characters'**
  String forumRequestDescriptionTooLong(int param1);

  /// No description provided for @forumRequestIconTooLong.
  ///
  /// In en, this message translates to:
  /// **'Icon cannot exceed {param1} characters'**
  String forumRequestIconTooLong(int param1);

  /// No description provided for @forumRequestSubmitFailed.
  ///
  /// In en, this message translates to:
  /// **'Submission failed, please check if the input is correct'**
  String get forumRequestSubmitFailed;

  /// No description provided for @forumRequestLoginExpired.
  ///
  /// In en, this message translates to:
  /// **'Login expired, please login again'**
  String get forumRequestLoginExpired;

  /// No description provided for @activityWaitingExpertResponse.
  ///
  /// In en, this message translates to:
  /// **'Waiting for Expert Response'**
  String get activityWaitingExpertResponse;

  /// No description provided for @activityContinuePayment.
  ///
  /// In en, this message translates to:
  /// **'Continue Payment'**
  String get activityContinuePayment;

  /// No description provided for @serviceApplied.
  ///
  /// In en, this message translates to:
  /// **'Applied'**
  String get serviceApplied;

  /// No description provided for @serviceWaitingExpertResponse.
  ///
  /// In en, this message translates to:
  /// **'Waiting for Expert Response'**
  String get serviceWaitingExpertResponse;

  /// No description provided for @serviceContinuePayment.
  ///
  /// In en, this message translates to:
  /// **'Continue Payment'**
  String get serviceContinuePayment;

  /// No description provided for @serviceUnderReview.
  ///
  /// In en, this message translates to:
  /// **'Under Review'**
  String get serviceUnderReview;

  /// No description provided for @serviceApplyAgain.
  ///
  /// In en, this message translates to:
  /// **'Apply Again'**
  String get serviceApplyAgain;

  /// No description provided for @serviceInProgress.
  ///
  /// In en, this message translates to:
  /// **'Service in Progress'**
  String get serviceInProgress;

  /// No description provided for @taskDetailConfirmDeadline.
  ///
  /// In en, this message translates to:
  /// **'Confirm deadline'**
  String get taskDetailConfirmDeadline;

  /// No description provided for @taskDetailPlatformServiceFee.
  ///
  /// In en, this message translates to:
  /// **'Platform service fee'**
  String get taskDetailPlatformServiceFee;

  /// No description provided for @taskDetailServiceFeeRate.
  ///
  /// In en, this message translates to:
  /// **'Service fee rate'**
  String get taskDetailServiceFeeRate;

  /// No description provided for @taskDetailServiceFeeAmount.
  ///
  /// In en, this message translates to:
  /// **'Service fee'**
  String get taskDetailServiceFeeAmount;

  /// No description provided for @taskDetailCountdownRemainingDays.
  ///
  /// In en, this message translates to:
  /// **'{param1} days {param2} hrs {param3} min remaining'**
  String taskDetailCountdownRemainingDays(int param1, int param2, int param3);

  /// No description provided for @taskDetailCountdownRemainingHours.
  ///
  /// In en, this message translates to:
  /// **'{param1} hrs {param2} min {param3} sec remaining'**
  String taskDetailCountdownRemainingHours(int param1, int param2, int param3);

  /// No description provided for @taskDetailCountdownRemainingMinutes.
  ///
  /// In en, this message translates to:
  /// **'{param1} min {param2} sec remaining'**
  String taskDetailCountdownRemainingMinutes(int param1, int param2);

  /// No description provided for @taskDetailCountdownRemainingSeconds.
  ///
  /// In en, this message translates to:
  /// **'{param1} sec remaining'**
  String taskDetailCountdownRemainingSeconds(int param1);

  /// No description provided for @taskDetailTaskCompletedTitle.
  ///
  /// In en, this message translates to:
  /// **'Task completed'**
  String get taskDetailTaskCompletedTitle;

  /// No description provided for @taskDetailTaskCompletedUploadHint.
  ///
  /// In en, this message translates to:
  /// **'You have completed this task. You may upload evidence images or add a text description (optional) for the poster to confirm.'**
  String get taskDetailTaskCompletedUploadHint;

  /// No description provided for @taskDetailSectionTextOptional.
  ///
  /// In en, this message translates to:
  /// **'Text description (optional)'**
  String get taskDetailSectionTextOptional;

  /// No description provided for @taskDetailSectionEvidenceImagesOptional.
  ///
  /// In en, this message translates to:
  /// **'Evidence images (optional)'**
  String get taskDetailSectionEvidenceImagesOptional;

  /// No description provided for @taskDetailSectionEvidenceFilesOptional.
  ///
  /// In en, this message translates to:
  /// **'Evidence files (optional)'**
  String get taskDetailSectionEvidenceFilesOptional;

  /// No description provided for @taskDetailSectionCompletionEvidenceOptional.
  ///
  /// In en, this message translates to:
  /// **'Completion evidence (optional)'**
  String get taskDetailSectionCompletionEvidenceOptional;

  /// No description provided for @taskDetailTextLimit500.
  ///
  /// In en, this message translates to:
  /// **'Text description must not exceed 500 characters'**
  String get taskDetailTextLimit500;

  /// No description provided for @taskDetailImageLimit5mb5.
  ///
  /// In en, this message translates to:
  /// **'Max 5MB per image, up to 5 images'**
  String get taskDetailImageLimit5mb5;

  /// No description provided for @taskDetailAddImage.
  ///
  /// In en, this message translates to:
  /// **'Add image'**
  String get taskDetailAddImage;

  /// No description provided for @taskDetailUploadProgress.
  ///
  /// In en, this message translates to:
  /// **'Upload progress'**
  String get taskDetailUploadProgress;

  /// No description provided for @taskDetailUploadingCount.
  ///
  /// In en, this message translates to:
  /// **'Uploading {param1}/{param2}...'**
  String taskDetailUploadingCount(int param1, int param2);

  /// No description provided for @taskDetailConfirmCompleteTaskButton.
  ///
  /// In en, this message translates to:
  /// **'Confirm task complete'**
  String get taskDetailConfirmCompleteTaskButton;

  /// No description provided for @taskDetailConfirmTaskCompleteAlertTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm task complete'**
  String get taskDetailConfirmTaskCompleteAlertTitle;

  /// No description provided for @taskDetailConfirmTaskCompleteAlertMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure this task is complete? It will be sent to the poster for confirmation.'**
  String get taskDetailConfirmTaskCompleteAlertMessage;

  /// No description provided for @taskDetailConfirmTaskCompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm task complete'**
  String get taskDetailConfirmTaskCompleteTitle;

  /// No description provided for @taskDetailConfirmTaskCompleteHint.
  ///
  /// In en, this message translates to:
  /// **'You have confirmed this task is complete. You may upload evidence images (optional), e.g. screenshots or acceptance records.'**
  String get taskDetailConfirmTaskCompleteHint;

  /// No description provided for @taskDetailConfirmCompleteButton.
  ///
  /// In en, this message translates to:
  /// **'Confirm complete'**
  String get taskDetailConfirmCompleteButton;

  /// No description provided for @taskDetailPleaseConfirmComplete.
  ///
  /// In en, this message translates to:
  /// **'Please confirm task complete'**
  String get taskDetailPleaseConfirmComplete;

  /// No description provided for @taskDetailAutoConfirmSoon.
  ///
  /// In en, this message translates to:
  /// **'Will auto-confirm soon. Please confirm now.'**
  String get taskDetailAutoConfirmSoon;

  /// No description provided for @taskDetailConfirmNow.
  ///
  /// In en, this message translates to:
  /// **'Confirm now'**
  String get taskDetailConfirmNow;

  /// No description provided for @taskDetailWaitingPosterConfirm.
  ///
  /// In en, this message translates to:
  /// **'Waiting for poster to confirm'**
  String get taskDetailWaitingPosterConfirm;

  /// No description provided for @taskDetailAutoConfirmOnExpiry.
  ///
  /// In en, this message translates to:
  /// **'(Will auto-confirm on expiry)'**
  String get taskDetailAutoConfirmOnExpiry;

  /// No description provided for @taskDetailDisputeDetail.
  ///
  /// In en, this message translates to:
  /// **'Task dispute details'**
  String get taskDetailDisputeDetail;

  /// No description provided for @taskDetailDeadlineLabel.
  ///
  /// In en, this message translates to:
  /// **'Deadline'**
  String get taskDetailDeadlineLabel;

  /// No description provided for @taskDetailNoUploadableImages.
  ///
  /// In en, this message translates to:
  /// **'No images to upload'**
  String get taskDetailNoUploadableImages;

  /// No description provided for @taskDetailImageSizeErrorFormat.
  ///
  /// In en, this message translates to:
  /// **'Image {param1} is still too large after compression ({param2}MB). Please choose a smaller image.'**
  String taskDetailImageSizeErrorFormat(int param1, double param2);

  /// No description provided for @taskDetailImageTooLargeSelectFormat.
  ///
  /// In en, this message translates to:
  /// **'Image too large ({param1}MB). Please choose a smaller image.'**
  String taskDetailImageTooLargeSelectFormat(double param1);

  /// No description provided for @taskDetailMaxImages5.
  ///
  /// In en, this message translates to:
  /// **'Maximum 5 images allowed'**
  String get taskDetailMaxImages5;

  /// No description provided for @taskDetailCompleteTaskNavTitle.
  ///
  /// In en, this message translates to:
  /// **'Complete Task'**
  String get taskDetailCompleteTaskNavTitle;

  /// No description provided for @taskDetailTaskCompletionEvidence.
  ///
  /// In en, this message translates to:
  /// **'Task completion evidence'**
  String get taskDetailTaskCompletionEvidence;

  /// No description provided for @taskDetailImageConvertError.
  ///
  /// In en, this message translates to:
  /// **'Unable to convert image data'**
  String get taskDetailImageConvertError;

  /// No description provided for @taskDetailImageProcessErrorFormat.
  ///
  /// In en, this message translates to:
  /// **'Image {param1} could not be processed. Please choose again.'**
  String taskDetailImageProcessErrorFormat(int param1);

  /// No description provided for @taskDetailCompletedCountFormat.
  ///
  /// In en, this message translates to:
  /// **'{param1} completed'**
  String taskDetailCompletedCountFormat(int param1);

  /// No description provided for @refundSubmitRebuttalEvidence.
  ///
  /// In en, this message translates to:
  /// **'Submit rebuttal evidence'**
  String get refundSubmitRebuttalEvidence;

  /// No description provided for @refundSubmitRebuttalNavTitle.
  ///
  /// In en, this message translates to:
  /// **'Submit rebuttal'**
  String get refundSubmitRebuttalNavTitle;

  /// No description provided for @refundViewHistory.
  ///
  /// In en, this message translates to:
  /// **'View history'**
  String get refundViewHistory;

  /// No description provided for @refundViewHistoryRecords.
  ///
  /// In en, this message translates to:
  /// **'View history records'**
  String get refundViewHistoryRecords;

  /// No description provided for @refundWithdrawApplication.
  ///
  /// In en, this message translates to:
  /// **'Withdraw refund application'**
  String get refundWithdrawApplication;

  /// No description provided for @refundWithdrawApplicationMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to withdraw this refund application? This cannot be undone.'**
  String get refundWithdrawApplicationMessage;

  /// No description provided for @refundWithdrawing.
  ///
  /// In en, this message translates to:
  /// **'Withdrawing...'**
  String get refundWithdrawing;

  /// No description provided for @refundWithdrawApply.
  ///
  /// In en, this message translates to:
  /// **'Withdraw application'**
  String get refundWithdrawApply;

  /// No description provided for @refundTaskIncompleteApplyRefund.
  ///
  /// In en, this message translates to:
  /// **'Task incomplete (apply for refund)'**
  String get refundTaskIncompleteApplyRefund;

  /// No description provided for @refundHistory.
  ///
  /// In en, this message translates to:
  /// **'Refund history'**
  String get refundHistory;

  /// No description provided for @refundReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Refund reason: {param1}'**
  String refundReasonLabel(String param1);

  /// No description provided for @refundTypeFull.
  ///
  /// In en, this message translates to:
  /// **'Full refund'**
  String get refundTypeFull;

  /// No description provided for @refundTypePartial.
  ///
  /// In en, this message translates to:
  /// **'Partial refund'**
  String get refundTypePartial;

  /// No description provided for @refundAdminCommentLabel.
  ///
  /// In en, this message translates to:
  /// **'Admin note: {param1}'**
  String refundAdminCommentLabel(String param1);

  /// No description provided for @refundTakerRebuttal.
  ///
  /// In en, this message translates to:
  /// **'Taker rebuttal'**
  String get refundTakerRebuttal;

  /// No description provided for @refundEvidenceFilesCount.
  ///
  /// In en, this message translates to:
  /// **'{param1} evidence file(s) uploaded'**
  String refundEvidenceFilesCount(int param1);

  /// No description provided for @refundNoHistory.
  ///
  /// In en, this message translates to:
  /// **'No refund history yet'**
  String get refundNoHistory;

  /// No description provided for @refundReasonTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason type:'**
  String get refundReasonTypeLabel;

  /// No description provided for @refundTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Refund type:'**
  String get refundTypeLabel;

  /// No description provided for @refundReviewTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Review time: {param1}'**
  String refundReviewTimeLabel(String param1);

  /// No description provided for @refundApplyTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Application time: {param1}'**
  String refundApplyTimeLabel(String param1);

  /// No description provided for @refundApplyRefund.
  ///
  /// In en, this message translates to:
  /// **'Apply for refund'**
  String get refundApplyRefund;

  /// No description provided for @refundApplyRefundHint.
  ///
  /// In en, this message translates to:
  /// **'Please describe the refund reason in detail and upload evidence (e.g. screenshots, chat logs). An admin will review within 3-5 business days.'**
  String get refundApplyRefundHint;

  /// No description provided for @refundReasonTypeRequired.
  ///
  /// In en, this message translates to:
  /// **'Refund reason type *'**
  String get refundReasonTypeRequired;

  /// No description provided for @refundReasonTypePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Select refund reason type'**
  String get refundReasonTypePlaceholder;

  /// No description provided for @refundPartialAmountTooHigh.
  ///
  /// In en, this message translates to:
  /// **'Partial refund amount cannot be greater than or equal to task amount. Please choose full refund.'**
  String get refundPartialAmountTooHigh;

  /// No description provided for @refundAmountExceedsTask.
  ///
  /// In en, this message translates to:
  /// **'Refund amount cannot exceed task amount (£{param1})'**
  String refundAmountExceedsTask(double param1);

  /// No description provided for @refundAmountMustBePositive.
  ///
  /// In en, this message translates to:
  /// **'Refund amount must be a number greater than 0'**
  String get refundAmountMustBePositive;

  /// No description provided for @refundRatioRange.
  ///
  /// In en, this message translates to:
  /// **'Refund percentage must be between 0-100'**
  String get refundRatioRange;

  /// No description provided for @refundReasonDetailRequired.
  ///
  /// In en, this message translates to:
  /// **'Refund reason details *'**
  String get refundReasonDetailRequired;

  /// No description provided for @refundReasonMinLength.
  ///
  /// In en, this message translates to:
  /// **'Refund reason must be at least 10 characters'**
  String get refundReasonMinLength;

  /// No description provided for @refundTypeRequired.
  ///
  /// In en, this message translates to:
  /// **'Refund type *'**
  String get refundTypeRequired;

  /// No description provided for @refundAmountOrRatioRequired.
  ///
  /// In en, this message translates to:
  /// **'Refund amount or ratio *'**
  String get refundAmountOrRatioRequired;

  /// No description provided for @refundAmountPound.
  ///
  /// In en, this message translates to:
  /// **'Refund amount (£)'**
  String get refundAmountPound;

  /// No description provided for @refundRatioPercent.
  ///
  /// In en, this message translates to:
  /// **'Refund ratio (%)'**
  String get refundRatioPercent;

  /// No description provided for @refundTaskAmountFormat.
  ///
  /// In en, this message translates to:
  /// **'Task amount: £{param1}'**
  String refundTaskAmountFormat(double param1);

  /// No description provided for @refundRefundAmountFormat.
  ///
  /// In en, this message translates to:
  /// **'Refund amount: £{param1}'**
  String refundRefundAmountFormat(double param1);

  /// No description provided for @refundSubmitRefundApplication.
  ///
  /// In en, this message translates to:
  /// **'Submit refund application'**
  String get refundSubmitRefundApplication;

  /// No description provided for @refundNoDisputeRecords.
  ///
  /// In en, this message translates to:
  /// **'No dispute records yet'**
  String get refundNoDisputeRecords;

  /// No description provided for @refundRebuttalDescription.
  ///
  /// In en, this message translates to:
  /// **'Rebuttal description'**
  String get refundRebuttalDescription;

  /// No description provided for @refundRebuttalMinLength.
  ///
  /// In en, this message translates to:
  /// **'Rebuttal description must be at least 10 characters'**
  String get refundRebuttalMinLength;

  /// No description provided for @refundUploadLimit5.
  ///
  /// In en, this message translates to:
  /// **'Up to 5 images or files, max 5MB each'**
  String get refundUploadLimit5;

  /// No description provided for @refundSelectImage.
  ///
  /// In en, this message translates to:
  /// **'Select image'**
  String get refundSelectImage;

  /// No description provided for @refundStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status: {param1}'**
  String refundStatusLabel(String param1);

  /// No description provided for @refundRebuttalHint.
  ///
  /// In en, this message translates to:
  /// **'Please describe the task completion and upload evidence (e.g. screenshots, files). Your rebuttal will help the admin make a fair decision.'**
  String get refundRebuttalHint;

  /// No description provided for @refundHistorySheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Refund history'**
  String get refundHistorySheetTitle;

  /// No description provided for @disputeActorPoster.
  ///
  /// In en, this message translates to:
  /// **'Poster'**
  String get disputeActorPoster;

  /// No description provided for @disputeActorTaker.
  ///
  /// In en, this message translates to:
  /// **'Taker'**
  String get disputeActorTaker;

  /// No description provided for @disputeActorAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get disputeActorAdmin;

  /// No description provided for @disputeNoRecords.
  ///
  /// In en, this message translates to:
  /// **'No dispute records'**
  String get disputeNoRecords;

  /// No description provided for @disputeStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending Review'**
  String get disputeStatusPending;

  /// No description provided for @disputeStatusProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get disputeStatusProcessing;

  /// No description provided for @disputeStatusApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get disputeStatusApproved;

  /// No description provided for @disputeStatusRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get disputeStatusRejected;

  /// No description provided for @disputeStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get disputeStatusCompleted;

  /// No description provided for @disputeStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get disputeStatusCancelled;

  /// No description provided for @disputeStatusResolved.
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get disputeStatusResolved;

  /// No description provided for @disputeStatusDismissed.
  ///
  /// In en, this message translates to:
  /// **'Dismissed'**
  String get disputeStatusDismissed;

  /// No description provided for @refundReasonCompletionTime.
  ///
  /// In en, this message translates to:
  /// **'Unsatisfied with completion time'**
  String get refundReasonCompletionTime;

  /// No description provided for @refundReasonNotCompleted.
  ///
  /// In en, this message translates to:
  /// **'Taker did not complete at all'**
  String get refundReasonNotCompleted;

  /// No description provided for @refundReasonQualityIssue.
  ///
  /// In en, this message translates to:
  /// **'Quality issue'**
  String get refundReasonQualityIssue;

  /// No description provided for @refundReasonOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get refundReasonOther;

  /// No description provided for @refundStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get refundStatusPending;

  /// No description provided for @refundStatusProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get refundStatusProcessing;

  /// No description provided for @refundStatusApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get refundStatusApproved;

  /// No description provided for @refundStatusRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get refundStatusRejected;

  /// No description provided for @refundStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get refundStatusCompleted;

  /// No description provided for @refundStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get refundStatusCancelled;

  /// No description provided for @refundStatusUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown status'**
  String get refundStatusUnknown;

  /// No description provided for @refundStatusPendingFull.
  ///
  /// In en, this message translates to:
  /// **'Refund pending review'**
  String get refundStatusPendingFull;

  /// No description provided for @refundStatusProcessingFull.
  ///
  /// In en, this message translates to:
  /// **'Refund processing'**
  String get refundStatusProcessingFull;

  /// No description provided for @refundStatusApprovedFull.
  ///
  /// In en, this message translates to:
  /// **'Refund approved'**
  String get refundStatusApprovedFull;

  /// No description provided for @refundStatusRejectedFull.
  ///
  /// In en, this message translates to:
  /// **'Refund rejected'**
  String get refundStatusRejectedFull;

  /// No description provided for @refundStatusCompletedFull.
  ///
  /// In en, this message translates to:
  /// **'Refund completed'**
  String get refundStatusCompletedFull;

  /// No description provided for @refundStatusCancelledFull.
  ///
  /// In en, this message translates to:
  /// **'Refund cancelled'**
  String get refundStatusCancelledFull;

  /// No description provided for @refundDescPending.
  ///
  /// In en, this message translates to:
  /// **'Your refund has been submitted. Admin will review within 3-5 business days.'**
  String get refundDescPending;

  /// No description provided for @refundDescProcessing.
  ///
  /// In en, this message translates to:
  /// **'Refund is being processed. Please wait.'**
  String get refundDescProcessing;

  /// No description provided for @refundDescApprovedAmount.
  ///
  /// In en, this message translates to:
  /// **'Refund amount: £{param2}{param1}. Will be returned in 5-10 business days.'**
  String refundDescApprovedAmount(String param1, double param2);

  /// No description provided for @refundDescApprovedGeneric.
  ///
  /// In en, this message translates to:
  /// **'Will be returned to your original payment method in 5-10 business days.'**
  String get refundDescApprovedGeneric;

  /// No description provided for @refundDescRejectedReason.
  ///
  /// In en, this message translates to:
  /// **'Rejection reason: {param1}'**
  String refundDescRejectedReason(String param1);

  /// No description provided for @refundDescRejectedGeneric.
  ///
  /// In en, this message translates to:
  /// **'Refund has been rejected.'**
  String get refundDescRejectedGeneric;

  /// No description provided for @refundDescCompletedAmount.
  ///
  /// In en, this message translates to:
  /// **'Refund amount: £{param2}{param1}. Returned to your original payment method.'**
  String refundDescCompletedAmount(String param1, double param2);

  /// No description provided for @refundDescCompletedGeneric.
  ///
  /// In en, this message translates to:
  /// **'Refund returned to your original payment method.'**
  String get refundDescCompletedGeneric;

  /// No description provided for @refundDescCancelled.
  ///
  /// In en, this message translates to:
  /// **'Refund cancelled.'**
  String get refundDescCancelled;

  /// No description provided for @commonUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get commonUnknown;

  /// No description provided for @commonOr.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get commonOr;

  /// No description provided for @fleaMarketProductTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Enter product title'**
  String get fleaMarketProductTitleHint;

  /// No description provided for @fleaMarketDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Describe your product in detail'**
  String get fleaMarketDescriptionHint;

  /// No description provided for @fleaMarketPriceAndTrade.
  ///
  /// In en, this message translates to:
  /// **'Price & Transaction'**
  String get fleaMarketPriceAndTrade;

  /// No description provided for @fleaMarketFillRequired.
  ///
  /// In en, this message translates to:
  /// **'Please fill in all required fields'**
  String get fleaMarketFillRequired;

  /// No description provided for @fleaMarketLocation.
  ///
  /// In en, this message translates to:
  /// **'Transaction Location'**
  String get fleaMarketLocation;

  /// No description provided for @taskPreferencesTypes.
  ///
  /// In en, this message translates to:
  /// **'Preferred Task Types'**
  String get taskPreferencesTypes;

  /// No description provided for @taskPreferencesTypesDesc.
  ///
  /// In en, this message translates to:
  /// **'Select the task types you are interested in'**
  String get taskPreferencesTypesDesc;

  /// No description provided for @taskPreferencesLocations.
  ///
  /// In en, this message translates to:
  /// **'Preferred Locations'**
  String get taskPreferencesLocations;

  /// No description provided for @taskPreferencesLocationsDesc.
  ///
  /// In en, this message translates to:
  /// **'Select locations where you prefer to complete tasks'**
  String get taskPreferencesLocationsDesc;

  /// No description provided for @taskPreferencesLevels.
  ///
  /// In en, this message translates to:
  /// **'Preferred Task Levels'**
  String get taskPreferencesLevels;

  /// No description provided for @taskPreferencesLevelsDesc.
  ///
  /// In en, this message translates to:
  /// **'Select the task levels you want to receive'**
  String get taskPreferencesLevelsDesc;

  /// No description provided for @taskPreferencesMinDeadlineDesc.
  ///
  /// In en, this message translates to:
  /// **'Only show tasks with deadline longer than the set days'**
  String get taskPreferencesMinDeadlineDesc;

  /// No description provided for @vipPleaseSelect.
  ///
  /// In en, this message translates to:
  /// **'Please Select a Plan'**
  String get vipPleaseSelect;

  /// No description provided for @commonNoResults.
  ///
  /// In en, this message translates to:
  /// **'No Results'**
  String get commonNoResults;

  /// No description provided for @taskExpertSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search experts by name or skill...'**
  String get taskExpertSearchHint;

  /// No description provided for @taskExpertNoResults.
  ///
  /// In en, this message translates to:
  /// **'No experts found matching your search'**
  String get taskExpertNoResults;

  /// No description provided for @taskExpertServiceDetail.
  ///
  /// In en, this message translates to:
  /// **'Service Detail'**
  String get taskExpertServiceDetail;

  /// No description provided for @taskExpertPrice.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get taskExpertPrice;

  /// No description provided for @taskExpertDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get taskExpertDescription;

  /// No description provided for @taskExpertCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get taskExpertCategory;

  /// No description provided for @taskExpertDeliveryTime.
  ///
  /// In en, this message translates to:
  /// **'Delivery Time'**
  String get taskExpertDeliveryTime;

  /// No description provided for @taskExpertMyApplications.
  ///
  /// In en, this message translates to:
  /// **'My Service Applications'**
  String get taskExpertMyApplications;

  /// No description provided for @taskExpertNoApplications.
  ///
  /// In en, this message translates to:
  /// **'No Applications'**
  String get taskExpertNoApplications;

  /// No description provided for @taskExpertNoApplicationsMessage.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t submitted any service applications yet'**
  String get taskExpertNoApplicationsMessage;

  /// No description provided for @taskExpertIntro.
  ///
  /// In en, this message translates to:
  /// **'Task Experts'**
  String get taskExpertIntro;

  /// No description provided for @taskExpertIntroTitle.
  ///
  /// In en, this message translates to:
  /// **'Become a Task Expert'**
  String get taskExpertIntroTitle;

  /// No description provided for @taskExpertIntroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Showcase your skills and earn more from completing tasks'**
  String get taskExpertIntroSubtitle;

  /// No description provided for @taskExpertBenefit1Title.
  ///
  /// In en, this message translates to:
  /// **'Verified Expert Badge'**
  String get taskExpertBenefit1Title;

  /// No description provided for @taskExpertBenefit1Desc.
  ///
  /// In en, this message translates to:
  /// **'Stand out with a verified expert badge on your profile'**
  String get taskExpertBenefit1Desc;

  /// No description provided for @taskExpertBenefit2Title.
  ///
  /// In en, this message translates to:
  /// **'Priority Matching'**
  String get taskExpertBenefit2Title;

  /// No description provided for @taskExpertBenefit2Desc.
  ///
  /// In en, this message translates to:
  /// **'Get matched with tasks that match your expertise first'**
  String get taskExpertBenefit2Desc;

  /// No description provided for @taskExpertBenefit3Title.
  ///
  /// In en, this message translates to:
  /// **'Higher Earnings'**
  String get taskExpertBenefit3Title;

  /// No description provided for @taskExpertBenefit3Desc.
  ///
  /// In en, this message translates to:
  /// **'Experts earn up to 20% more on task completions'**
  String get taskExpertBenefit3Desc;

  /// No description provided for @leaderboardScore.
  ///
  /// In en, this message translates to:
  /// **'Score'**
  String get leaderboardScore;

  /// No description provided for @leaderboardApplySuccess.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard application submitted successfully'**
  String get leaderboardApplySuccess;

  /// No description provided for @leaderboardDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Describe this leaderboard'**
  String get leaderboardDescriptionHint;

  /// No description provided for @leaderboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get leaderboardTitle;

  /// No description provided for @leaderboardTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Enter leaderboard title'**
  String get leaderboardTitleHint;

  /// No description provided for @leaderboardRules.
  ///
  /// In en, this message translates to:
  /// **'Rules'**
  String get leaderboardRules;

  /// No description provided for @leaderboardRulesHint.
  ///
  /// In en, this message translates to:
  /// **'Describe the rules for this leaderboard'**
  String get leaderboardRulesHint;

  /// No description provided for @leaderboardLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get leaderboardLocation;

  /// No description provided for @leaderboardLocationHint.
  ///
  /// In en, this message translates to:
  /// **'Enter the location for this leaderboard'**
  String get leaderboardLocationHint;

  /// No description provided for @leaderboardApplicationReason.
  ///
  /// In en, this message translates to:
  /// **'Application Reason'**
  String get leaderboardApplicationReason;

  /// No description provided for @leaderboardApplicationReasonHint.
  ///
  /// In en, this message translates to:
  /// **'Why do you want to create this leaderboard?'**
  String get leaderboardApplicationReasonHint;

  /// No description provided for @leaderboardFillRequired.
  ///
  /// In en, this message translates to:
  /// **'Please fill in all required fields'**
  String get leaderboardFillRequired;

  /// No description provided for @leaderboardSubmitApply.
  ///
  /// In en, this message translates to:
  /// **'Submit Application'**
  String get leaderboardSubmitApply;

  /// No description provided for @leaderboardApply.
  ///
  /// In en, this message translates to:
  /// **'Apply for Leaderboard'**
  String get leaderboardApply;

  /// No description provided for @leaderboardItemScore.
  ///
  /// In en, this message translates to:
  /// **'Score'**
  String get leaderboardItemScore;

  /// No description provided for @leaderboardSubmitSuccess.
  ///
  /// In en, this message translates to:
  /// **'Entry submitted successfully'**
  String get leaderboardSubmitSuccess;

  /// No description provided for @leaderboardSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get leaderboardSubmit;

  /// No description provided for @paymentStripeConnect.
  ///
  /// In en, this message translates to:
  /// **'Stripe Connect Setup'**
  String get paymentStripeConnect;

  /// No description provided for @paymentConnectPayments.
  ///
  /// In en, this message translates to:
  /// **'Connect Payments'**
  String get paymentConnectPayments;

  /// No description provided for @paymentConnectPayouts.
  ///
  /// In en, this message translates to:
  /// **'Connect Payouts'**
  String get paymentConnectPayouts;

  /// No description provided for @paymentNoPayments.
  ///
  /// In en, this message translates to:
  /// **'No Payments'**
  String get paymentNoPayments;

  /// No description provided for @paymentNoPaymentsMessage.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have any payment records yet'**
  String get paymentNoPaymentsMessage;

  /// No description provided for @paymentNoPayouts.
  ///
  /// In en, this message translates to:
  /// **'No Payouts'**
  String get paymentNoPayouts;

  /// No description provided for @paymentNoPayoutsMessage.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have any payout records yet'**
  String get paymentNoPayoutsMessage;

  /// No description provided for @paymentExpired.
  ///
  /// In en, this message translates to:
  /// **'Payment Expired'**
  String get paymentExpired;

  /// No description provided for @paymentExpiredMessage.
  ///
  /// In en, this message translates to:
  /// **'Payment time has expired, please initiate payment again.'**
  String get paymentExpiredMessage;

  /// No description provided for @paymentCountdownTimeout.
  ///
  /// In en, this message translates to:
  /// **'Payment Timed Out'**
  String get paymentCountdownTimeout;

  /// No description provided for @paymentCountdownCompleteInTime.
  ///
  /// In en, this message translates to:
  /// **'Please complete payment within the time limit'**
  String get paymentCountdownCompleteInTime;

  /// No description provided for @paymentCountdownTimeLeft.
  ///
  /// In en, this message translates to:
  /// **'Time remaining: {time}'**
  String paymentCountdownTimeLeft(String time);

  /// No description provided for @paymentApplePayIOSOnly.
  ///
  /// In en, this message translates to:
  /// **'Apple Pay is only available on iOS devices'**
  String get paymentApplePayIOSOnly;

  /// No description provided for @paymentApplePayNotSupported.
  ///
  /// In en, this message translates to:
  /// **'Your device does not support Apple Pay, please use another payment method'**
  String get paymentApplePayNotSupported;

  /// No description provided for @paymentNetworkConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Network connection failed, please check your network and try again.'**
  String get paymentNetworkConnectionFailed;

  /// No description provided for @paymentRequestTimeout.
  ///
  /// In en, this message translates to:
  /// **'Request timeout, please try again later.'**
  String get paymentRequestTimeout;

  /// No description provided for @paymentRemainingTime.
  ///
  /// In en, this message translates to:
  /// **'Payment remaining time: {param1}'**
  String paymentRemainingTime(String param1);

  /// No description provided for @paymentOrderInfo.
  ///
  /// In en, this message translates to:
  /// **'Order Information'**
  String get paymentOrderInfo;

  /// No description provided for @paymentTaskNumber.
  ///
  /// In en, this message translates to:
  /// **'Task Number'**
  String get paymentTaskNumber;

  /// No description provided for @paymentOriginalPrice.
  ///
  /// In en, this message translates to:
  /// **'Original Price'**
  String get paymentOriginalPrice;

  /// No description provided for @paymentDiscount.
  ///
  /// In en, this message translates to:
  /// **'Discount ({param1})'**
  String paymentDiscount(String param1);

  /// No description provided for @paymentFinalAmount.
  ///
  /// In en, this message translates to:
  /// **'Final Payment Amount'**
  String get paymentFinalAmount;

  /// No description provided for @paymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment Method'**
  String get paymentMethod;

  /// No description provided for @paymentCreditDebitCard.
  ///
  /// In en, this message translates to:
  /// **'Credit/Debit Card'**
  String get paymentCreditDebitCard;

  /// No description provided for @paymentFastSecure.
  ///
  /// In en, this message translates to:
  /// **'Fast and secure payment'**
  String get paymentFastSecure;

  /// No description provided for @paymentWeChatPay.
  ///
  /// In en, this message translates to:
  /// **'WeChat Pay'**
  String get paymentWeChatPay;

  /// No description provided for @paymentAlipay.
  ///
  /// In en, this message translates to:
  /// **'Alipay'**
  String get paymentAlipay;

  /// No description provided for @paymentCouponSelected.
  ///
  /// In en, this message translates to:
  /// **'Coupon Selected'**
  String get paymentCouponSelected;

  /// No description provided for @paymentSelectCoupon.
  ///
  /// In en, this message translates to:
  /// **'Select Coupon'**
  String get paymentSelectCoupon;

  /// No description provided for @paymentConfirmFree.
  ///
  /// In en, this message translates to:
  /// **'Confirm (Free)'**
  String get paymentConfirmFree;

  /// No description provided for @paymentPayNow.
  ///
  /// In en, this message translates to:
  /// **'Pay Now {param1}'**
  String paymentPayNow(String param1);

  /// No description provided for @paymentCancelPayment.
  ///
  /// In en, this message translates to:
  /// **'Cancel Payment'**
  String get paymentCancelPayment;

  /// No description provided for @paymentCancelPaymentConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to cancel payment?'**
  String get paymentCancelPaymentConfirm;

  /// No description provided for @paymentContinuePayment.
  ///
  /// In en, this message translates to:
  /// **'Continue Payment'**
  String get paymentContinuePayment;

  /// No description provided for @paymentLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Load Failed'**
  String get paymentLoadFailed;

  /// No description provided for @paymentCoupon.
  ///
  /// In en, this message translates to:
  /// **'Coupon'**
  String get paymentCoupon;

  /// No description provided for @paymentApplePayLabel.
  ///
  /// In en, this message translates to:
  /// **'Task #{param1}'**
  String paymentApplePayLabel(int param1);

  /// No description provided for @profileTaskCount.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get profileTaskCount;

  /// No description provided for @profileRating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get profileRating;

  /// No description provided for @profileNoRecentTasks.
  ///
  /// In en, this message translates to:
  /// **'No recent tasks'**
  String get profileNoRecentTasks;

  /// No description provided for @notificationMarkAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get notificationMarkAllRead;

  /// No description provided for @notificationEmpty.
  ///
  /// In en, this message translates to:
  /// **'No Notifications'**
  String get notificationEmpty;

  /// No description provided for @notificationEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'You\'re all caught up! No new notifications.'**
  String get notificationEmptyMessage;

  /// No description provided for @notificationAll.
  ///
  /// In en, this message translates to:
  /// **'All Notifications'**
  String get notificationAll;

  /// No description provided for @notificationTask.
  ///
  /// In en, this message translates to:
  /// **'Task Notifications'**
  String get notificationTask;

  /// No description provided for @notificationForum.
  ///
  /// In en, this message translates to:
  /// **'Forum Notifications'**
  String get notificationForum;

  /// No description provided for @notificationInteraction.
  ///
  /// In en, this message translates to:
  /// **'Interaction Messages'**
  String get notificationInteraction;

  /// No description provided for @errorNetworkTimeout.
  ///
  /// In en, this message translates to:
  /// **'Network connection timed out'**
  String get errorNetworkTimeout;

  /// No description provided for @errorRequestFailedGeneric.
  ///
  /// In en, this message translates to:
  /// **'Request failed'**
  String get errorRequestFailedGeneric;

  /// No description provided for @errorRequestCancelled.
  ///
  /// In en, this message translates to:
  /// **'Request cancelled'**
  String get errorRequestCancelled;

  /// No description provided for @errorNetworkConnection.
  ///
  /// In en, this message translates to:
  /// **'Network connection failed'**
  String get errorNetworkConnection;

  /// No description provided for @errorUnknownGeneric.
  ///
  /// In en, this message translates to:
  /// **'An unknown error occurred'**
  String get errorUnknownGeneric;

  /// No description provided for @errorInsufficientFunds.
  ///
  /// In en, this message translates to:
  /// **'Insufficient balance. Please change payment method or top up.'**
  String get errorInsufficientFunds;

  /// No description provided for @errorCardDeclined.
  ///
  /// In en, this message translates to:
  /// **'Card declined. Please change card or contact your bank.'**
  String get errorCardDeclined;

  /// No description provided for @errorExpiredCard.
  ///
  /// In en, this message translates to:
  /// **'Card expired. Please use a different card.'**
  String get errorExpiredCard;

  /// No description provided for @searchTitle.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchTitle;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search tasks, posts, items'**
  String get searchHint;

  /// No description provided for @searchTryDifferent.
  ///
  /// In en, this message translates to:
  /// **'Try searching with different keywords'**
  String get searchTryDifferent;

  /// No description provided for @searchResultCount.
  ///
  /// In en, this message translates to:
  /// **'Found {count} results'**
  String searchResultCount(int count);

  /// No description provided for @searchRecentSearches.
  ///
  /// In en, this message translates to:
  /// **'Recent searches'**
  String get searchRecentSearches;

  /// No description provided for @searchClearHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear search history'**
  String get searchClearHistory;

  /// No description provided for @networkOnline.
  ///
  /// In en, this message translates to:
  /// **'Network restored'**
  String get networkOnline;

  /// No description provided for @notificationPermissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification Permission Required'**
  String get notificationPermissionTitle;

  /// No description provided for @notificationPermissionDescription.
  ///
  /// In en, this message translates to:
  /// **'Stay updated with:\n\n• Task status updates\n• New message alerts\n• Task matching recommendations\n• Promotional notifications'**
  String get notificationPermissionDescription;

  /// No description provided for @notificationPermissionEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable Notifications'**
  String get notificationPermissionEnable;

  /// No description provided for @notificationPermissionSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get notificationPermissionSkip;

  /// No description provided for @feedbackPublishSuccess.
  ///
  /// In en, this message translates to:
  /// **'Published successfully'**
  String get feedbackPublishSuccess;

  /// No description provided for @feedbackPublishFailed.
  ///
  /// In en, this message translates to:
  /// **'Publish failed'**
  String get feedbackPublishFailed;

  /// No description provided for @feedbackTaskPublishSuccess.
  ///
  /// In en, this message translates to:
  /// **'Task published successfully'**
  String get feedbackTaskPublishSuccess;

  /// No description provided for @feedbackPostPublishSuccess.
  ///
  /// In en, this message translates to:
  /// **'Post published successfully'**
  String get feedbackPostPublishSuccess;

  /// No description provided for @feedbackFillTitleAndContent.
  ///
  /// In en, this message translates to:
  /// **'Please fill in title and content'**
  String get feedbackFillTitleAndContent;

  /// No description provided for @feedbackSelectCategory.
  ///
  /// In en, this message translates to:
  /// **'Please select a category'**
  String get feedbackSelectCategory;

  /// No description provided for @feedbackPickImageFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to pick image: {error}'**
  String feedbackPickImageFailed(String error);

  /// No description provided for @feedbackSaveSuccess.
  ///
  /// In en, this message translates to:
  /// **'Saved successfully'**
  String get feedbackSaveSuccess;

  /// No description provided for @feedbackSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed'**
  String get feedbackSaveFailed;

  /// No description provided for @feedbackOperationSuccess.
  ///
  /// In en, this message translates to:
  /// **'Operation successful'**
  String get feedbackOperationSuccess;

  /// No description provided for @feedbackOperationFailed.
  ///
  /// In en, this message translates to:
  /// **'Operation failed'**
  String get feedbackOperationFailed;

  /// No description provided for @feedbackLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Load failed'**
  String get feedbackLoadFailed;

  /// No description provided for @feedbackNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Network error, please try again'**
  String get feedbackNetworkError;

  /// No description provided for @feedbackDeleteSuccess.
  ///
  /// In en, this message translates to:
  /// **'Deleted successfully'**
  String get feedbackDeleteSuccess;

  /// No description provided for @feedbackCopySuccess.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get feedbackCopySuccess;

  /// No description provided for @errorPageNotFound.
  ///
  /// In en, this message translates to:
  /// **'Page not found: {uri}'**
  String errorPageNotFound(String uri);

  /// No description provided for @errorServerTitle.
  ///
  /// In en, this message translates to:
  /// **'Server Error'**
  String get errorServerTitle;

  /// No description provided for @errorServerMessage.
  ///
  /// In en, this message translates to:
  /// **'Server is temporarily unavailable, please try again later'**
  String get errorServerMessage;

  /// No description provided for @errorLoadFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Load Failed'**
  String get errorLoadFailedTitle;

  /// No description provided for @errorLoadFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'An error occurred while loading data'**
  String get errorLoadFailedMessage;

  /// No description provided for @errorUnauthorizedTitle.
  ///
  /// In en, this message translates to:
  /// **'Unauthorized'**
  String get errorUnauthorizedTitle;

  /// No description provided for @errorUnauthorizedMessage.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to access this content'**
  String get errorUnauthorizedMessage;

  /// No description provided for @errorContentNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Content Not Found'**
  String get errorContentNotFoundTitle;

  /// No description provided for @errorContentNotFoundMessage.
  ///
  /// In en, this message translates to:
  /// **'The content you are looking for does not exist or has been removed'**
  String get errorContentNotFoundMessage;

  /// No description provided for @errorNetworkTitle.
  ///
  /// In en, this message translates to:
  /// **'Network Connection Failed'**
  String get errorNetworkTitle;

  /// No description provided for @errorNetworkMessage.
  ///
  /// In en, this message translates to:
  /// **'Please check your network connection and try again'**
  String get errorNetworkMessage;

  /// No description provided for @emptyNoData.
  ///
  /// In en, this message translates to:
  /// **'No Data'**
  String get emptyNoData;

  /// No description provided for @emptyNoMessages.
  ///
  /// In en, this message translates to:
  /// **'No Messages'**
  String get emptyNoMessages;

  /// No description provided for @emptyNoMessagesDescription.
  ///
  /// In en, this message translates to:
  /// **'No messages received yet'**
  String get emptyNoMessagesDescription;

  /// No description provided for @emptyNoTasksDescription.
  ///
  /// In en, this message translates to:
  /// **'No tasks available. Tap below to create a new task'**
  String get emptyNoTasksDescription;

  /// No description provided for @emptyNoSearchResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'No Results Found'**
  String get emptyNoSearchResultsTitle;

  /// No description provided for @emptyNoSearchResultsDescription.
  ///
  /// In en, this message translates to:
  /// **'No related content found'**
  String get emptyNoSearchResultsDescription;

  /// No description provided for @emptyNoSearchResultsWithKeyword.
  ///
  /// In en, this message translates to:
  /// **'No results found for \"{keyword}\"'**
  String emptyNoSearchResultsWithKeyword(String keyword);

  /// No description provided for @emptyNoFavoritesDescription.
  ///
  /// In en, this message translates to:
  /// **'Your favorites will appear here'**
  String get emptyNoFavoritesDescription;

  /// No description provided for @emptyNoNotificationsDescription.
  ///
  /// In en, this message translates to:
  /// **'Your notifications will appear here'**
  String get emptyNoNotificationsDescription;

  /// No description provided for @sidebarDiscover.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get sidebarDiscover;

  /// No description provided for @sidebarAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get sidebarAccount;

  /// No description provided for @sidebarWallet.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get sidebarWallet;

  /// No description provided for @commonOpenInBrowser.
  ///
  /// In en, this message translates to:
  /// **'Open in browser'**
  String get commonOpenInBrowser;

  /// No description provided for @commonFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get commonFree;

  /// No description provided for @commonRetryText.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetryText;

  /// No description provided for @locationTaskLocation.
  ///
  /// In en, this message translates to:
  /// **'Task Location'**
  String get locationTaskLocation;

  /// No description provided for @locationGetFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to get location'**
  String get locationGetFailed;

  /// No description provided for @locationEnableLocationService.
  ///
  /// In en, this message translates to:
  /// **'Please enable location services on your device first'**
  String get locationEnableLocationService;

  /// No description provided for @locationOpenMapFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to open map'**
  String get locationOpenMapFailed;

  /// No description provided for @notificationPermissionMessage.
  ///
  /// In en, this message translates to:
  /// **'You have denied notification permission. Please enable it in system settings.'**
  String get notificationPermissionMessage;

  /// No description provided for @notificationPermissionLater.
  ///
  /// In en, this message translates to:
  /// **'Maybe Later'**
  String get notificationPermissionLater;

  /// No description provided for @permissionRequired.
  ///
  /// In en, this message translates to:
  /// **'{permissionName} permission required'**
  String permissionRequired(String permissionName);

  /// No description provided for @permissionEnableInSettings.
  ///
  /// In en, this message translates to:
  /// **'Please enable {permissionName} permission in system settings and try again'**
  String permissionEnableInSettings(String permissionName);

  /// No description provided for @permissionRequiredForFeature.
  ///
  /// In en, this message translates to:
  /// **'This feature requires {permissionName} permission to work'**
  String permissionRequiredForFeature(String permissionName);

  /// No description provided for @badgeStudent.
  ///
  /// In en, this message translates to:
  /// **'Student'**
  String get badgeStudent;

  /// No description provided for @badgeExpert.
  ///
  /// In en, this message translates to:
  /// **'Expert'**
  String get badgeExpert;

  /// No description provided for @activityCampusActivities.
  ///
  /// In en, this message translates to:
  /// **'Campus Activities'**
  String get activityCampusActivities;

  /// No description provided for @activityDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Activity Details'**
  String get activityDetailTitle;

  /// No description provided for @activityInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Activity Info'**
  String get activityInfoTitle;

  /// No description provided for @activityParticipantCount.
  ///
  /// In en, this message translates to:
  /// **'Participants'**
  String get activityParticipantCount;

  /// No description provided for @activityDiscount.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get activityDiscount;

  /// No description provided for @activityRewardType.
  ///
  /// In en, this message translates to:
  /// **'Reward Type'**
  String get activityRewardType;

  /// No description provided for @activitySignupSuccess.
  ///
  /// In en, this message translates to:
  /// **'Registration Successful'**
  String get activitySignupSuccess;

  /// No description provided for @authResetPassword.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get authResetPassword;

  /// No description provided for @authCodeSent.
  ///
  /// In en, this message translates to:
  /// **'Verification code sent'**
  String get authCodeSent;

  /// No description provided for @authEnterEmailPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Enter email address'**
  String get authEnterEmailPlaceholder;

  /// No description provided for @authPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPasswordLabel;

  /// No description provided for @authPasswordPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Enter password'**
  String get authPasswordPlaceholder;

  /// No description provided for @authCodePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Enter verification code'**
  String get authCodePlaceholder;

  /// No description provided for @authPhonePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'7XXX XXXXXX'**
  String get authPhonePlaceholder;

  /// No description provided for @authConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get authConfirmPassword;

  /// No description provided for @authConfirmPasswordPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Enter password again'**
  String get authConfirmPasswordPlaceholder;

  /// No description provided for @authPasswordRequirement.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters with letters and numbers'**
  String get authPasswordRequirement;

  /// No description provided for @authPleaseAgreeToTerms.
  ///
  /// In en, this message translates to:
  /// **'Please read and agree to the Terms and Privacy Policy'**
  String get authPleaseAgreeToTerms;

  /// No description provided for @authPleaseEnterValidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address'**
  String get authPleaseEnterValidEmail;

  /// No description provided for @authIAgreePrefix.
  ///
  /// In en, this message translates to:
  /// **'I have read and agree to the '**
  String get authIAgreePrefix;

  /// No description provided for @authAnd.
  ///
  /// In en, this message translates to:
  /// **' and '**
  String get authAnd;

  /// No description provided for @forumPostDetail.
  ///
  /// In en, this message translates to:
  /// **'Post Detail'**
  String get forumPostDetail;

  /// No description provided for @forumWriteComment.
  ///
  /// In en, this message translates to:
  /// **'Write a comment...'**
  String get forumWriteComment;

  /// No description provided for @chatUserTitle.
  ///
  /// In en, this message translates to:
  /// **'User {userId}'**
  String chatUserTitle(String userId);

  /// No description provided for @chatTaskTitle.
  ///
  /// In en, this message translates to:
  /// **'Task {taskId}'**
  String chatTaskTitle(int taskId);

  /// No description provided for @chatInputHint.
  ///
  /// In en, this message translates to:
  /// **'Type a message...'**
  String get chatInputHint;

  /// No description provided for @chatImageLabel.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get chatImageLabel;

  /// No description provided for @chatSendImageConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Send image'**
  String get chatSendImageConfirmTitle;

  /// No description provided for @chatCameraLabel.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get chatCameraLabel;

  /// No description provided for @chatTaskCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get chatTaskCompleted;

  /// No description provided for @chatHasIssue.
  ///
  /// In en, this message translates to:
  /// **'Has Issue'**
  String get chatHasIssue;

  /// No description provided for @chatRequestRefund.
  ///
  /// In en, this message translates to:
  /// **'Request Refund'**
  String get chatRequestRefund;

  /// No description provided for @chatUploadProof.
  ///
  /// In en, this message translates to:
  /// **'Upload Proof'**
  String get chatUploadProof;

  /// No description provided for @chatViewDetail.
  ///
  /// In en, this message translates to:
  /// **'View Details'**
  String get chatViewDetail;

  /// No description provided for @chatCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get chatCopy;

  /// No description provided for @chatTranslate.
  ///
  /// In en, this message translates to:
  /// **'Translate'**
  String get chatTranslate;

  /// No description provided for @chatCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get chatCopied;

  /// No description provided for @chatPinToTop.
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get chatPinToTop;

  /// No description provided for @chatUnpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get chatUnpin;

  /// No description provided for @chatDeleteChat.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get chatDeleteChat;

  /// No description provided for @chatDeletedHint.
  ///
  /// In en, this message translates to:
  /// **'Chat deleted. It will reappear when new messages arrive.'**
  String get chatDeletedHint;

  /// No description provided for @chatPinnedHint.
  ///
  /// In en, this message translates to:
  /// **'Chat pinned to top'**
  String get chatPinnedHint;

  /// No description provided for @chatUnpinnedHint.
  ///
  /// In en, this message translates to:
  /// **'Chat unpinned'**
  String get chatUnpinnedHint;

  /// No description provided for @chatTaskDetailLabel.
  ///
  /// In en, this message translates to:
  /// **'Task Details'**
  String get chatTaskDetailLabel;

  /// No description provided for @chatAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get chatAddressLabel;

  /// No description provided for @tasksSortLatest.
  ///
  /// In en, this message translates to:
  /// **'Latest'**
  String get tasksSortLatest;

  /// No description provided for @tasksSortHighestPay.
  ///
  /// In en, this message translates to:
  /// **'Highest Pay'**
  String get tasksSortHighestPay;

  /// No description provided for @tasksSortDeadline.
  ///
  /// In en, this message translates to:
  /// **'Ending Soon'**
  String get tasksSortDeadline;

  /// No description provided for @tasksProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing...'**
  String get tasksProcessing;

  /// No description provided for @tasksApplyForTask.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get tasksApplyForTask;

  /// No description provided for @tasksCancelApplication.
  ///
  /// In en, this message translates to:
  /// **'Cancel Application'**
  String get tasksCancelApplication;

  /// No description provided for @tasksCompleteTask.
  ///
  /// In en, this message translates to:
  /// **'Complete Task'**
  String get tasksCompleteTask;

  /// No description provided for @tasksConfirmComplete.
  ///
  /// In en, this message translates to:
  /// **'Confirm Complete'**
  String get tasksConfirmComplete;

  /// No description provided for @fleaMarketChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get fleaMarketChat;

  /// No description provided for @fleaMarketPurchaseInDev.
  ///
  /// In en, this message translates to:
  /// **'Purchase feature coming soon'**
  String get fleaMarketPurchaseInDev;

  /// No description provided for @fleaMarketSeller.
  ///
  /// In en, this message translates to:
  /// **'Seller'**
  String get fleaMarketSeller;

  /// No description provided for @fleaMarketCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'List Item'**
  String get fleaMarketCreateTitle;

  /// No description provided for @fleaMarketTitlePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Enter item title'**
  String get fleaMarketTitlePlaceholder;

  /// No description provided for @fleaMarketDescPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Describe your item...'**
  String get fleaMarketDescPlaceholder;

  /// No description provided for @fleaMarketSelectCategory.
  ///
  /// In en, this message translates to:
  /// **'Select category'**
  String get fleaMarketSelectCategory;

  /// No description provided for @fleaMarketLocationPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'e.g. North Campus Gate'**
  String get fleaMarketLocationPlaceholder;

  /// No description provided for @fleaMarketSelectImageFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to select image'**
  String get fleaMarketSelectImageFailed;

  /// No description provided for @fleaMarketInvalidPrice.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid price'**
  String get fleaMarketInvalidPrice;

  /// No description provided for @profileEditProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get profileEditProfileTitle;

  /// No description provided for @profileSaveButton.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get profileSaveButton;

  /// No description provided for @profileNamePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Enter name'**
  String get profileNamePlaceholder;

  /// No description provided for @profileBioPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Tell us about yourself...'**
  String get profileBioPlaceholder;

  /// No description provided for @profileLocationPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'e.g. London'**
  String get profileLocationPlaceholder;

  /// No description provided for @profileMyPostsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No Posts'**
  String get profileMyPostsEmpty;

  /// No description provided for @profileAcceptedTasks.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get profileAcceptedTasks;

  /// No description provided for @walletPointsBalance.
  ///
  /// In en, this message translates to:
  /// **'Points Balance'**
  String get walletPointsBalance;

  /// No description provided for @walletUnwithdrawnIncome.
  ///
  /// In en, this message translates to:
  /// **'Unwithdrawn Income'**
  String get walletUnwithdrawnIncome;

  /// No description provided for @walletTotalEarned.
  ///
  /// In en, this message translates to:
  /// **'Total Earned'**
  String get walletTotalEarned;

  /// No description provided for @walletTotalSpent.
  ///
  /// In en, this message translates to:
  /// **'Total Spent'**
  String get walletTotalSpent;

  /// No description provided for @walletPaymentAccount.
  ///
  /// In en, this message translates to:
  /// **'Payment Account'**
  String get walletPaymentAccount;

  /// No description provided for @walletPayoutRecords.
  ///
  /// In en, this message translates to:
  /// **'Payout Records'**
  String get walletPayoutRecords;

  /// No description provided for @walletTransactionRecords.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get walletTransactionRecords;

  /// No description provided for @walletNoTransactions.
  ///
  /// In en, this message translates to:
  /// **'No Transactions'**
  String get walletNoTransactions;

  /// No description provided for @walletViewMore.
  ///
  /// In en, this message translates to:
  /// **'View More Transactions'**
  String get walletViewMore;

  /// No description provided for @walletMyCoupons.
  ///
  /// In en, this message translates to:
  /// **'My Coupons'**
  String get walletMyCoupons;

  /// No description provided for @walletNoCoupons.
  ///
  /// In en, this message translates to:
  /// **'No Coupons'**
  String get walletNoCoupons;

  /// No description provided for @settingsGoLogin.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get settingsGoLogin;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsThemeSystem;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsPaymentReceiving.
  ///
  /// In en, this message translates to:
  /// **'Payment & Receiving'**
  String get settingsPaymentReceiving;

  /// No description provided for @settingsExpenseManagement.
  ///
  /// In en, this message translates to:
  /// **'Expense Management'**
  String get settingsExpenseManagement;

  /// No description provided for @settingsPaymentHistory.
  ///
  /// In en, this message translates to:
  /// **'Payment History'**
  String get settingsPaymentHistory;

  /// No description provided for @settingsCookiePolicy.
  ///
  /// In en, this message translates to:
  /// **'Cookie Policy'**
  String get settingsCookiePolicy;

  /// No description provided for @settingsEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get settingsEmail;

  /// No description provided for @settingsOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get settingsOther;

  /// No description provided for @settingsClearCache.
  ///
  /// In en, this message translates to:
  /// **'Clear Cache'**
  String get settingsClearCache;

  /// No description provided for @settingsDangerZone.
  ///
  /// In en, this message translates to:
  /// **'Danger Zone'**
  String get settingsDangerZone;

  /// No description provided for @couponPointsTab.
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get couponPointsTab;

  /// No description provided for @couponCouponsTab.
  ///
  /// In en, this message translates to:
  /// **'Coupons'**
  String get couponCouponsTab;

  /// No description provided for @couponCheckInTab.
  ///
  /// In en, this message translates to:
  /// **'Check-in'**
  String get couponCheckInTab;

  /// No description provided for @couponRedeemReward.
  ///
  /// In en, this message translates to:
  /// **'Redeem Reward'**
  String get couponRedeemReward;

  /// No description provided for @couponRedeemCode.
  ///
  /// In en, this message translates to:
  /// **'Redeem Code'**
  String get couponRedeemCode;

  /// No description provided for @couponNoPointsRecords.
  ///
  /// In en, this message translates to:
  /// **'No Points Records'**
  String get couponNoPointsRecords;

  /// No description provided for @couponEnterInviteCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter Invite Code'**
  String get couponEnterInviteCodeTitle;

  /// No description provided for @couponEnterInviteCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Enter invite code or redeem code'**
  String get couponEnterInviteCodeHint;

  /// No description provided for @couponNoCoupons.
  ///
  /// In en, this message translates to:
  /// **'No Coupons'**
  String get couponNoCoupons;

  /// No description provided for @couponClaim.
  ///
  /// In en, this message translates to:
  /// **'Claim'**
  String get couponClaim;

  /// No description provided for @customerServiceRateTitle.
  ///
  /// In en, this message translates to:
  /// **'Rate Support'**
  String get customerServiceRateTitle;

  /// No description provided for @customerServiceRateHint.
  ///
  /// In en, this message translates to:
  /// **'Leave your feedback (optional)'**
  String get customerServiceRateHint;

  /// No description provided for @customerServiceEndTitle.
  ///
  /// In en, this message translates to:
  /// **'End Conversation'**
  String get customerServiceEndTitle;

  /// No description provided for @customerServiceEndMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to end this conversation?'**
  String get customerServiceEndMessage;

  /// No description provided for @customerServiceEndButton.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get customerServiceEndButton;

  /// No description provided for @customerServiceRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get customerServiceRefresh;

  /// No description provided for @notificationSystemTab.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get notificationSystemTab;

  /// No description provided for @notificationInteractionTab.
  ///
  /// In en, this message translates to:
  /// **'Interactions'**
  String get notificationInteractionTab;

  /// No description provided for @notificationTaskChatTitle.
  ///
  /// In en, this message translates to:
  /// **'Task Chat'**
  String get notificationTaskChatTitle;

  /// No description provided for @notificationNoTaskChats.
  ///
  /// In en, this message translates to:
  /// **'No Task Chats'**
  String get notificationNoTaskChats;

  /// No description provided for @onboardingWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Link²Ur'**
  String get onboardingWelcome;

  /// No description provided for @onboardingPublishTask.
  ///
  /// In en, this message translates to:
  /// **'Post Tasks'**
  String get onboardingPublishTask;

  /// No description provided for @onboardingAcceptTask.
  ///
  /// In en, this message translates to:
  /// **'Accept Tasks'**
  String get onboardingAcceptTask;

  /// No description provided for @onboardingSafePayment.
  ///
  /// In en, this message translates to:
  /// **'Safe Payment'**
  String get onboardingSafePayment;

  /// No description provided for @onboardingSafePaymentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Funds are protected'**
  String get onboardingSafePaymentSubtitle;

  /// No description provided for @onboardingCommunity.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get onboardingCommunity;

  /// No description provided for @searchTasks.
  ///
  /// In en, this message translates to:
  /// **'Search Tasks'**
  String get searchTasks;

  /// No description provided for @searchFleaMarket.
  ///
  /// In en, this message translates to:
  /// **'Search Items'**
  String get searchFleaMarket;

  /// No description provided for @searchForum.
  ///
  /// In en, this message translates to:
  /// **'Search Posts'**
  String get searchForum;

  /// No description provided for @searchTasksTitle.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get searchTasksTitle;

  /// No description provided for @searchForumTitle.
  ///
  /// In en, this message translates to:
  /// **'Forum'**
  String get searchForumTitle;

  /// No description provided for @searchFleaMarketTitle.
  ///
  /// In en, this message translates to:
  /// **'Flea Market'**
  String get searchFleaMarketTitle;

  /// No description provided for @searchExpertsTitle.
  ///
  /// In en, this message translates to:
  /// **'Experts'**
  String get searchExpertsTitle;

  /// No description provided for @searchActivitiesTitle.
  ///
  /// In en, this message translates to:
  /// **'Activities'**
  String get searchActivitiesTitle;

  /// No description provided for @searchLeaderboardsTitle.
  ///
  /// In en, this message translates to:
  /// **'Leaderboards'**
  String get searchLeaderboardsTitle;

  /// No description provided for @searchLeaderboardItemsTitle.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard Items'**
  String get searchLeaderboardItemsTitle;

  /// No description provided for @searchForumCategoriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Forum Categories'**
  String get searchForumCategoriesTitle;

  /// No description provided for @leaderboardRankLabel.
  ///
  /// In en, this message translates to:
  /// **'Rank'**
  String get leaderboardRankLabel;

  /// No description provided for @taskExpertNotFound.
  ///
  /// In en, this message translates to:
  /// **'Expert not found'**
  String get taskExpertNotFound;

  /// No description provided for @taskExpertCompletedOrders.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get taskExpertCompletedOrders;

  /// No description provided for @taskExpertServices.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get taskExpertServices;

  /// No description provided for @taskExpertBook.
  ///
  /// In en, this message translates to:
  /// **'Book'**
  String get taskExpertBook;

  /// No description provided for @createTaskDescPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Describe task requirements in detail...'**
  String get createTaskDescPlaceholder;

  /// No description provided for @createTaskLocationPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Enter task location'**
  String get createTaskLocationPlaceholder;

  /// No description provided for @createTaskPublish.
  ///
  /// In en, this message translates to:
  /// **'Publish Task'**
  String get createTaskPublish;

  /// No description provided for @infoFAQTitle.
  ///
  /// In en, this message translates to:
  /// **'FAQ'**
  String get infoFAQTitle;

  /// No description provided for @infoAboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get infoAboutTitle;

  /// No description provided for @infoFAQAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get infoFAQAccountTitle;

  /// No description provided for @infoFAQTaskTitle.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get infoFAQTaskTitle;

  /// No description provided for @infoFAQPaymentTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment & Security'**
  String get infoFAQPaymentTitle;

  /// No description provided for @infoTermsTitle.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get infoTermsTitle;

  /// No description provided for @infoPrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get infoPrivacyTitle;

  /// No description provided for @infoCookieTitle.
  ///
  /// In en, this message translates to:
  /// **'Cookie Policy'**
  String get infoCookieTitle;

  /// No description provided for @infoVipCenter.
  ///
  /// In en, this message translates to:
  /// **'VIP Center'**
  String get infoVipCenter;

  /// No description provided for @infoVipPriority.
  ///
  /// In en, this message translates to:
  /// **'Priority Orders'**
  String get infoVipPriority;

  /// No description provided for @infoVipBadge.
  ///
  /// In en, this message translates to:
  /// **'VIP Badge'**
  String get infoVipBadge;

  /// No description provided for @infoVipFeeReduction.
  ///
  /// In en, this message translates to:
  /// **'Fee Reduction'**
  String get infoVipFeeReduction;

  /// No description provided for @infoVipCustomerService.
  ///
  /// In en, this message translates to:
  /// **'VIP Support'**
  String get infoVipCustomerService;

  /// No description provided for @infoVipPointsBoost.
  ///
  /// In en, this message translates to:
  /// **'Points Boost'**
  String get infoVipPointsBoost;

  /// No description provided for @infoVipSubscribe.
  ///
  /// In en, this message translates to:
  /// **'Subscribe to VIP'**
  String get infoVipSubscribe;

  /// No description provided for @infoVipPriorityRecommend.
  ///
  /// In en, this message translates to:
  /// **'Priority Listing'**
  String get infoVipPriorityRecommend;

  /// No description provided for @infoVipBadgeLabel.
  ///
  /// In en, this message translates to:
  /// **'VIP Badge'**
  String get infoVipBadgeLabel;

  /// No description provided for @infoVipFeeDiscount.
  ///
  /// In en, this message translates to:
  /// **'Fee Discount'**
  String get infoVipFeeDiscount;

  /// No description provided for @infoVipExclusiveCoupon.
  ///
  /// In en, this message translates to:
  /// **'Exclusive Coupons'**
  String get infoVipExclusiveCoupon;

  /// No description provided for @infoVipDataAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Data Analytics'**
  String get infoVipDataAnalytics;

  /// No description provided for @infoVipMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get infoVipMonthly;

  /// No description provided for @infoVipYearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get infoVipYearly;

  /// No description provided for @vipPurchaseConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get vipPurchaseConfirm;

  /// No description provided for @vipPurchaseRestoreMessage.
  ///
  /// In en, this message translates to:
  /// **'Purchase history checked. Active subscriptions will be restored automatically.'**
  String get vipPurchaseRestoreMessage;

  /// No description provided for @vipPurchaseNoPlans.
  ///
  /// In en, this message translates to:
  /// **'No VIP plans available'**
  String get vipPurchaseNoPlans;

  /// No description provided for @vipPurchaseReload.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get vipPurchaseReload;

  /// No description provided for @homeSecondHandMarket.
  ///
  /// In en, this message translates to:
  /// **'Second-hand Market'**
  String get homeSecondHandMarket;

  /// No description provided for @homeSecondHandSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pre-owned items at great prices'**
  String get homeSecondHandSubtitle;

  /// No description provided for @homeStudentVerification.
  ///
  /// In en, this message translates to:
  /// **'Student Verification'**
  String get homeStudentVerification;

  /// No description provided for @homeStudentVerificationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Verify to unlock more benefits'**
  String get homeStudentVerificationSubtitle;

  /// No description provided for @homeBecomeExpert.
  ///
  /// In en, this message translates to:
  /// **'Become an Expert'**
  String get homeBecomeExpert;

  /// No description provided for @homeBecomeExpertSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Showcase skills, get more opportunities'**
  String get homeBecomeExpertSubtitle;

  /// No description provided for @homeNewUserReward.
  ///
  /// In en, this message translates to:
  /// **'New User Reward'**
  String get homeNewUserReward;

  /// No description provided for @homeNewUserRewardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Complete first order to earn'**
  String get homeNewUserRewardSubtitle;

  /// No description provided for @homeInviteFriends.
  ///
  /// In en, this message translates to:
  /// **'Invite Friends'**
  String get homeInviteFriends;

  /// No description provided for @homeInviteFriendsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Invite friends to earn points'**
  String get homeInviteFriendsSubtitle;

  /// No description provided for @homeDailyCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Daily Check-in'**
  String get homeDailyCheckIn;

  /// No description provided for @homeDailyCheckInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Check in daily for rewards'**
  String get homeDailyCheckInSubtitle;

  /// No description provided for @homeCampusLife.
  ///
  /// In en, this message translates to:
  /// **'Campus Life Sharing'**
  String get homeCampusLife;

  /// No description provided for @homeUsedBooks.
  ///
  /// In en, this message translates to:
  /// **'Used Books for Sale'**
  String get homeUsedBooks;

  /// No description provided for @homeWeeklyExperts.
  ///
  /// In en, this message translates to:
  /// **'Weekly Expert Leaderboard'**
  String get homeWeeklyExperts;

  /// No description provided for @homeLoadNearbyTasks.
  ///
  /// In en, this message translates to:
  /// **'Load Nearby Tasks'**
  String get homeLoadNearbyTasks;

  /// No description provided for @homeBrowseExperts.
  ///
  /// In en, this message translates to:
  /// **'Browse Experts'**
  String get homeBrowseExperts;

  /// No description provided for @homeDiscoverMore.
  ///
  /// In en, this message translates to:
  /// **'Discover More'**
  String get homeDiscoverMore;

  /// No description provided for @discoveryFeedTypePost.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get discoveryFeedTypePost;

  /// No description provided for @discoveryFeedTypeProduct.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get discoveryFeedTypeProduct;

  /// No description provided for @discoveryFeedTypeCompetitorReview.
  ///
  /// In en, this message translates to:
  /// **'Competitor Review'**
  String get discoveryFeedTypeCompetitorReview;

  /// No description provided for @discoveryFeedTypeServiceReview.
  ///
  /// In en, this message translates to:
  /// **'Service Review'**
  String get discoveryFeedTypeServiceReview;

  /// No description provided for @discoveryFeedTypeRanking.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get discoveryFeedTypeRanking;

  /// No description provided for @discoveryFeedTypeService.
  ///
  /// In en, this message translates to:
  /// **'Expert Service'**
  String get discoveryFeedTypeService;

  /// No description provided for @mainPublishFleaMarket.
  ///
  /// In en, this message translates to:
  /// **'List Item'**
  String get mainPublishFleaMarket;

  /// No description provided for @linkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get linkCopied;

  /// No description provided for @paymentAlipaySymbol.
  ///
  /// In en, this message translates to:
  /// **'A'**
  String get paymentAlipaySymbol;

  /// No description provided for @authResendCountdown.
  ///
  /// In en, this message translates to:
  /// **'Resend in {countdown}s'**
  String authResendCountdown(int countdown);

  /// No description provided for @authPasswordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get authPasswordsDoNotMatch;

  /// No description provided for @authPleaseEnterEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email'**
  String get authPleaseEnterEmail;

  /// No description provided for @authEmailFormatInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid email format'**
  String get authEmailFormatInvalid;

  /// No description provided for @authResetPasswordDesc.
  ///
  /// In en, this message translates to:
  /// **'Enter your registered email and we will send a verification code to help you reset your password.'**
  String get authResetPasswordDesc;

  /// No description provided for @authCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get authCreateAccount;

  /// No description provided for @authAlreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get authAlreadyHaveAccount;

  /// No description provided for @authNewPassword.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get authNewPassword;

  /// No description provided for @authEnterNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Please enter a new password'**
  String get authEnterNewPassword;

  /// No description provided for @authPasswordMinLength.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters'**
  String get authPasswordMinLength;

  /// No description provided for @authConfirmNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm New Password'**
  String get authConfirmNewPassword;

  /// No description provided for @authForgotPasswordQuestion.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get authForgotPasswordQuestion;

  /// No description provided for @authRegisterNewAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get authRegisterNewAccount;

  /// No description provided for @authRegisterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Join Link²Ur, start exchanging skills'**
  String get authRegisterSubtitle;

  /// No description provided for @homeLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load'**
  String get homeLoadFailed;

  /// No description provided for @homePublishTask.
  ///
  /// In en, this message translates to:
  /// **'Post Task'**
  String get homePublishTask;

  /// No description provided for @homeDeadlineExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get homeDeadlineExpired;

  /// No description provided for @homeDeadlineDays.
  ///
  /// In en, this message translates to:
  /// **'{days}d left'**
  String homeDeadlineDays(int days);

  /// No description provided for @homeDeadlineHours.
  ///
  /// In en, this message translates to:
  /// **'{hours}h left'**
  String homeDeadlineHours(int hours);

  /// No description provided for @homeDeadlineMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m left'**
  String homeDeadlineMinutes(int minutes);

  /// No description provided for @homeDefaultUser.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get homeDefaultUser;

  /// No description provided for @homeClassmate.
  ///
  /// In en, this message translates to:
  /// **'Linker'**
  String get homeClassmate;

  /// No description provided for @homePostedNewPost.
  ///
  /// In en, this message translates to:
  /// **'posted a new topic'**
  String get homePostedNewPost;

  /// No description provided for @homePostedNewProduct.
  ///
  /// In en, this message translates to:
  /// **'listed a new item'**
  String get homePostedNewProduct;

  /// No description provided for @homeSystemUser.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get homeSystemUser;

  /// No description provided for @homeCreatedLeaderboard.
  ///
  /// In en, this message translates to:
  /// **'created a new leaderboard'**
  String get homeCreatedLeaderboard;

  /// No description provided for @homeCampusLifeDesc.
  ///
  /// In en, this message translates to:
  /// **'Sharing my campus life'**
  String get homeCampusLifeDesc;

  /// No description provided for @homeSearchCategory.
  ///
  /// In en, this message translates to:
  /// **'Search categories'**
  String get homeSearchCategory;

  /// No description provided for @homeSearchTasks.
  ///
  /// In en, this message translates to:
  /// **'Search tasks'**
  String get homeSearchTasks;

  /// No description provided for @homeSearchFleaMarket.
  ///
  /// In en, this message translates to:
  /// **'Search marketplace'**
  String get homeSearchFleaMarket;

  /// No description provided for @homeSearchPosts.
  ///
  /// In en, this message translates to:
  /// **'Search posts'**
  String get homeSearchPosts;

  /// No description provided for @homeSearchQueryResult.
  ///
  /// In en, this message translates to:
  /// **'Search \"{query}\"'**
  String homeSearchQueryResult(String query);

  /// No description provided for @homePressEnterToSearch.
  ///
  /// In en, this message translates to:
  /// **'Press Enter to search'**
  String get homePressEnterToSearch;

  /// No description provided for @taskCategoryPickup.
  ///
  /// In en, this message translates to:
  /// **'Pickup'**
  String get taskCategoryPickup;

  /// No description provided for @taskCategoryTutoring.
  ///
  /// In en, this message translates to:
  /// **'Tutoring'**
  String get taskCategoryTutoring;

  /// No description provided for @taskCategoryMoving.
  ///
  /// In en, this message translates to:
  /// **'Moving'**
  String get taskCategoryMoving;

  /// No description provided for @taskCategoryPurchasing.
  ///
  /// In en, this message translates to:
  /// **'Purchasing'**
  String get taskCategoryPurchasing;

  /// No description provided for @taskCategoryDogWalking.
  ///
  /// In en, this message translates to:
  /// **'Dog Walking'**
  String get taskCategoryDogWalking;

  /// No description provided for @taskCategoryTranslation.
  ///
  /// In en, this message translates to:
  /// **'Translation'**
  String get taskCategoryTranslation;

  /// No description provided for @taskCategoryPhotography.
  ///
  /// In en, this message translates to:
  /// **'Photography'**
  String get taskCategoryPhotography;

  /// No description provided for @taskCategoryTutor.
  ///
  /// In en, this message translates to:
  /// **'Tutoring'**
  String get taskCategoryTutor;

  /// No description provided for @taskDetailProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing...'**
  String get taskDetailProcessing;

  /// No description provided for @taskDetailApplyForTask.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get taskDetailApplyForTask;

  /// No description provided for @taskDetailCancelApplication.
  ///
  /// In en, this message translates to:
  /// **'Cancel Application'**
  String get taskDetailCancelApplication;

  /// No description provided for @taskDetailCompleteTask.
  ///
  /// In en, this message translates to:
  /// **'Complete Task'**
  String get taskDetailCompleteTask;

  /// No description provided for @taskDetailParticipantCount.
  ///
  /// In en, this message translates to:
  /// **'Participants'**
  String get taskDetailParticipantCount;

  /// No description provided for @taskSortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get taskSortBy;

  /// No description provided for @taskSortLatest.
  ///
  /// In en, this message translates to:
  /// **'Latest'**
  String get taskSortLatest;

  /// No description provided for @taskSortHighestPay.
  ///
  /// In en, this message translates to:
  /// **'Highest Pay'**
  String get taskSortHighestPay;

  /// No description provided for @taskSortNearDeadline.
  ///
  /// In en, this message translates to:
  /// **'Near Deadline'**
  String get taskSortNearDeadline;

  /// No description provided for @taskDeadlineExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get taskDeadlineExpired;

  /// No description provided for @taskDeadlineMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m left'**
  String taskDeadlineMinutes(int minutes);

  /// No description provided for @taskDeadlineHours.
  ///
  /// In en, this message translates to:
  /// **'{hours}h left'**
  String taskDeadlineHours(int hours);

  /// No description provided for @taskDeadlineDays.
  ///
  /// In en, this message translates to:
  /// **'{days}d left'**
  String taskDeadlineDays(int days);

  /// No description provided for @taskDeadlineDate.
  ///
  /// In en, this message translates to:
  /// **'{month}/{day} deadline'**
  String taskDeadlineDate(int month, int day);

  /// No description provided for @taskCategoryHousekeepingLife.
  ///
  /// In en, this message translates to:
  /// **'Housekeeping'**
  String get taskCategoryHousekeepingLife;

  /// No description provided for @createTaskType.
  ///
  /// In en, this message translates to:
  /// **'Task Type'**
  String get createTaskType;

  /// No description provided for @createTaskTitleField.
  ///
  /// In en, this message translates to:
  /// **'Task Title'**
  String get createTaskTitleField;

  /// No description provided for @createTaskTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Enter task title'**
  String get createTaskTitleHint;

  /// No description provided for @createTaskDescHint.
  ///
  /// In en, this message translates to:
  /// **'Describe task requirements in detail...'**
  String get createTaskDescHint;

  /// No description provided for @createTaskLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get createTaskLocation;

  /// No description provided for @createTaskLocationHint.
  ///
  /// In en, this message translates to:
  /// **'Enter task location'**
  String get createTaskLocationHint;

  /// No description provided for @createTaskDeadline.
  ///
  /// In en, this message translates to:
  /// **'Deadline'**
  String get createTaskDeadline;

  /// No description provided for @createTaskSelectDeadline.
  ///
  /// In en, this message translates to:
  /// **'Select deadline'**
  String get createTaskSelectDeadline;

  /// No description provided for @createTaskCategoryDelivery.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get createTaskCategoryDelivery;

  /// No description provided for @createTaskCategoryShopping.
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get createTaskCategoryShopping;

  /// No description provided for @createTaskCategoryTutoring.
  ///
  /// In en, this message translates to:
  /// **'Tutoring'**
  String get createTaskCategoryTutoring;

  /// No description provided for @createTaskCategoryTranslation.
  ///
  /// In en, this message translates to:
  /// **'Translation'**
  String get createTaskCategoryTranslation;

  /// No description provided for @createTaskCategoryDesign.
  ///
  /// In en, this message translates to:
  /// **'Design'**
  String get createTaskCategoryDesign;

  /// No description provided for @createTaskCategoryProgramming.
  ///
  /// In en, this message translates to:
  /// **'Programming'**
  String get createTaskCategoryProgramming;

  /// No description provided for @createTaskCategoryWriting.
  ///
  /// In en, this message translates to:
  /// **'Writing'**
  String get createTaskCategoryWriting;

  /// No description provided for @createTaskCategoryPhotography.
  ///
  /// In en, this message translates to:
  /// **'Photography'**
  String get createTaskCategoryPhotography;

  /// No description provided for @createTaskCategoryMoving.
  ///
  /// In en, this message translates to:
  /// **'Moving'**
  String get createTaskCategoryMoving;

  /// No description provided for @createTaskCategoryCleaning.
  ///
  /// In en, this message translates to:
  /// **'Cleaning'**
  String get createTaskCategoryCleaning;

  /// No description provided for @createTaskCategoryRepair.
  ///
  /// In en, this message translates to:
  /// **'Repair'**
  String get createTaskCategoryRepair;

  /// No description provided for @createTaskCategoryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get createTaskCategoryOther;

  /// No description provided for @profileDirectRequestValidation.
  ///
  /// In en, this message translates to:
  /// **'Please fill in the title and a valid price (≥£1)'**
  String get profileDirectRequestValidation;

  /// No description provided for @profileDirectRequestHintLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get profileDirectRequestHintLocation;

  /// No description provided for @profileDirectRequestHintDeadline.
  ///
  /// In en, this message translates to:
  /// **'Deadline (optional)'**
  String get profileDirectRequestHintDeadline;

  /// No description provided for @taskTypeHousekeeping.
  ///
  /// In en, this message translates to:
  /// **'Housekeeping'**
  String get taskTypeHousekeeping;

  /// No description provided for @taskTypeCampusLife.
  ///
  /// In en, this message translates to:
  /// **'Campus Life'**
  String get taskTypeCampusLife;

  /// No description provided for @taskTypeSecondHandRental.
  ///
  /// In en, this message translates to:
  /// **'Second-hand & Rental'**
  String get taskTypeSecondHandRental;

  /// No description provided for @taskTypeErrandRunning.
  ///
  /// In en, this message translates to:
  /// **'Errand Running'**
  String get taskTypeErrandRunning;

  /// No description provided for @taskTypeSkillService.
  ///
  /// In en, this message translates to:
  /// **'Skill Service'**
  String get taskTypeSkillService;

  /// No description provided for @taskTypeSocialHelp.
  ///
  /// In en, this message translates to:
  /// **'Social Help'**
  String get taskTypeSocialHelp;

  /// No description provided for @taskTypeTransportation.
  ///
  /// In en, this message translates to:
  /// **'Transportation'**
  String get taskTypeTransportation;

  /// No description provided for @taskTypePetCare.
  ///
  /// In en, this message translates to:
  /// **'Pet Care'**
  String get taskTypePetCare;

  /// No description provided for @taskTypeLifeConvenience.
  ///
  /// In en, this message translates to:
  /// **'Life Convenience'**
  String get taskTypeLifeConvenience;

  /// No description provided for @taskTypeOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get taskTypeOther;

  /// No description provided for @taskTypeCampusLifeNeedVerify.
  ///
  /// In en, this message translates to:
  /// **'Publishing \"Campus Life\" tasks requires student email verification'**
  String get taskTypeCampusLifeNeedVerify;

  /// No description provided for @taskDetailNoImages.
  ///
  /// In en, this message translates to:
  /// **'No images'**
  String get taskDetailNoImages;

  /// No description provided for @forumUserFallback.
  ///
  /// In en, this message translates to:
  /// **'User {userId}'**
  String forumUserFallback(String userId);

  /// No description provided for @forumNoLeaderboard.
  ///
  /// In en, this message translates to:
  /// **'No leaderboard'**
  String get forumNoLeaderboard;

  /// No description provided for @forumNoLeaderboardMessage.
  ///
  /// In en, this message translates to:
  /// **'No leaderboard available'**
  String get forumNoLeaderboardMessage;

  /// No description provided for @forumNoPostsHint.
  ///
  /// In en, this message translates to:
  /// **'No posts yet. Tap below to create the first one!'**
  String get forumNoPostsHint;

  /// No description provided for @forumEnterTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter title'**
  String get forumEnterTitle;

  /// No description provided for @forumShareThoughts.
  ///
  /// In en, this message translates to:
  /// **'Share your thoughts...'**
  String get forumShareThoughts;

  /// No description provided for @forumSelectCategory.
  ///
  /// In en, this message translates to:
  /// **'Select category'**
  String get forumSelectCategory;

  /// No description provided for @settingsPleaseLoginFirst.
  ///
  /// In en, this message translates to:
  /// **'Please login first'**
  String get settingsPleaseLoginFirst;

  /// No description provided for @settingsUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get settingsUnknown;

  /// No description provided for @settingsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get settingsLoading;

  /// No description provided for @settingsNotBound.
  ///
  /// In en, this message translates to:
  /// **'Not linked'**
  String get settingsNotBound;

  /// No description provided for @settingsChinese.
  ///
  /// In en, this message translates to:
  /// **'Chinese'**
  String get settingsChinese;

  /// No description provided for @walletPayoutAccount.
  ///
  /// In en, this message translates to:
  /// **'Payout Account'**
  String get walletPayoutAccount;

  /// No description provided for @walletActivated.
  ///
  /// In en, this message translates to:
  /// **'Activated, ready to receive'**
  String get walletActivated;

  /// No description provided for @walletConnectedPending.
  ///
  /// In en, this message translates to:
  /// **'Connected, pending activation'**
  String get walletConnectedPending;

  /// No description provided for @walletNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get walletNotConnected;

  /// No description provided for @walletActivatedShort.
  ///
  /// In en, this message translates to:
  /// **'Activated'**
  String get walletActivatedShort;

  /// No description provided for @walletPendingActivation.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get walletPendingActivation;

  /// No description provided for @walletNotConnectedShort.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get walletNotConnectedShort;

  /// No description provided for @walletViewAccountDetail.
  ///
  /// In en, this message translates to:
  /// **'View account details'**
  String get walletViewAccountDetail;

  /// No description provided for @walletSetupPayoutAccount.
  ///
  /// In en, this message translates to:
  /// **'Setup payout account'**
  String get walletSetupPayoutAccount;

  /// No description provided for @walletPayoutRecordsFull.
  ///
  /// In en, this message translates to:
  /// **'Payout Records'**
  String get walletPayoutRecordsFull;

  /// No description provided for @walletWithdrawalRecords.
  ///
  /// In en, this message translates to:
  /// **'Withdrawal Records'**
  String get walletWithdrawalRecords;

  /// No description provided for @walletTransactionHistory.
  ///
  /// In en, this message translates to:
  /// **'Transaction History'**
  String get walletTransactionHistory;

  /// No description provided for @walletTopUp.
  ///
  /// In en, this message translates to:
  /// **'Top Up'**
  String get walletTopUp;

  /// No description provided for @walletTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get walletTransfer;

  /// No description provided for @walletViewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get walletViewAll;

  /// No description provided for @walletTransactionsDesc.
  ///
  /// In en, this message translates to:
  /// **'Your points transaction history will appear here'**
  String get walletTransactionsDesc;

  /// No description provided for @walletNoCouponsDesc.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have any coupons'**
  String get walletNoCouponsDesc;

  /// No description provided for @walletToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get walletToday;

  /// No description provided for @walletYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get walletYesterday;

  /// No description provided for @walletCheckingIn.
  ///
  /// In en, this message translates to:
  /// **'Checking in...'**
  String get walletCheckingIn;

  /// No description provided for @walletDailyCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Daily Check-in'**
  String get walletDailyCheckIn;

  /// No description provided for @myTasksTitle.
  ///
  /// In en, this message translates to:
  /// **'My Tasks'**
  String get myTasksTitle;

  /// No description provided for @myTasksAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get myTasksAccepted;

  /// No description provided for @myTasksPosted.
  ///
  /// In en, this message translates to:
  /// **'Posted'**
  String get myTasksPosted;

  /// No description provided for @myTasksGoAccept.
  ///
  /// In en, this message translates to:
  /// **'Browse Tasks'**
  String get myTasksGoAccept;

  /// No description provided for @profileBio.
  ///
  /// In en, this message translates to:
  /// **'Bio'**
  String get profileBio;

  /// No description provided for @profileBioHint.
  ///
  /// In en, this message translates to:
  /// **'Tell us about yourself...'**
  String get profileBioHint;

  /// No description provided for @profileCity.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get profileCity;

  /// No description provided for @profileCityHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. London'**
  String get profileCityHint;

  /// No description provided for @profileNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your name'**
  String get profileNameRequired;

  /// No description provided for @profileNameMinLength.
  ///
  /// In en, this message translates to:
  /// **'Name must be at least 3 characters'**
  String get profileNameMinLength;

  /// No description provided for @profileAnonymousUser.
  ///
  /// In en, this message translates to:
  /// **'Anonymous'**
  String get profileAnonymousUser;

  /// No description provided for @myPostsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No posts'**
  String get myPostsEmpty;

  /// No description provided for @myPostsEmptyDesc.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t posted anything yet'**
  String get myPostsEmptyDesc;

  /// No description provided for @fleaMarketSold.
  ///
  /// In en, this message translates to:
  /// **'Sold'**
  String get fleaMarketSold;

  /// No description provided for @fleaMarketDelisted.
  ///
  /// In en, this message translates to:
  /// **'Delisted'**
  String get fleaMarketDelisted;

  /// No description provided for @fleaMarketItemReserved.
  ///
  /// In en, this message translates to:
  /// **'Item Reserved'**
  String get fleaMarketItemReserved;

  /// No description provided for @fleaMarketCategoryAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get fleaMarketCategoryAll;

  /// No description provided for @fleaMarketCategoryDailyUse.
  ///
  /// In en, this message translates to:
  /// **'Daily Use'**
  String get fleaMarketCategoryDailyUse;

  /// No description provided for @fleaMarketImageSelectFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to select image'**
  String get fleaMarketImageSelectFailed;

  /// No description provided for @fleaMarketTitleMinLength.
  ///
  /// In en, this message translates to:
  /// **'Title must be at least 2 characters'**
  String get fleaMarketTitleMinLength;

  /// No description provided for @fleaMarketTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a title'**
  String get fleaMarketTitleRequired;

  /// No description provided for @fleaMarketDescOptional.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get fleaMarketDescOptional;

  /// No description provided for @fleaMarketDescHint.
  ///
  /// In en, this message translates to:
  /// **'Describe your item...'**
  String get fleaMarketDescHint;

  /// No description provided for @fleaMarketLocationOptional.
  ///
  /// In en, this message translates to:
  /// **'Location (optional)'**
  String get fleaMarketLocationOptional;

  /// No description provided for @fleaMarketLocationHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Campus North Gate'**
  String get fleaMarketLocationHint;

  /// No description provided for @fleaMarketPriceRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a price'**
  String get fleaMarketPriceRequired;

  /// No description provided for @fleaMarketCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get fleaMarketCategoryLabel;

  /// No description provided for @fleaMarketNoItemsHint.
  ///
  /// In en, this message translates to:
  /// **'No items yet. Tap below to list the first one!'**
  String get fleaMarketNoItemsHint;

  /// No description provided for @chatNoMessages.
  ///
  /// In en, this message translates to:
  /// **'No messages yet. Start a conversation!'**
  String get chatNoMessages;

  /// No description provided for @chatInProgress.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get chatInProgress;

  /// No description provided for @chatTaskClosed.
  ///
  /// In en, this message translates to:
  /// **'Task Closed'**
  String get chatTaskClosed;

  /// No description provided for @chatTaskClosedHint.
  ///
  /// In en, this message translates to:
  /// **'This task has been closed, messages are disabled'**
  String get chatTaskClosedHint;

  /// No description provided for @chatTaskCompletedConfirm.
  ///
  /// In en, this message translates to:
  /// **'Task completed, please confirm.'**
  String get chatTaskCompletedConfirm;

  /// No description provided for @chatHasIssueMessage.
  ///
  /// In en, this message translates to:
  /// **'I encountered some issues:'**
  String get chatHasIssueMessage;

  /// No description provided for @activityCheckLater.
  ///
  /// In en, this message translates to:
  /// **'Check back later'**
  String get activityCheckLater;

  /// No description provided for @activityNoAvailableActivities.
  ///
  /// In en, this message translates to:
  /// **'No activities available yet'**
  String get activityNoAvailableActivities;

  /// No description provided for @activityRegisterSuccess.
  ///
  /// In en, this message translates to:
  /// **'Registration successful'**
  String get activityRegisterSuccess;

  /// No description provided for @activityRegisterFailed.
  ///
  /// In en, this message translates to:
  /// **'Registration failed'**
  String get activityRegisterFailed;

  /// No description provided for @activityRegisterNow.
  ///
  /// In en, this message translates to:
  /// **'Register Now'**
  String get activityRegisterNow;

  /// No description provided for @activityRegistered.
  ///
  /// In en, this message translates to:
  /// **'Registered'**
  String get activityRegistered;

  /// No description provided for @activityFullSlots.
  ///
  /// In en, this message translates to:
  /// **'Full'**
  String get activityFullSlots;

  /// No description provided for @activityCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get activityCancelled;

  /// No description provided for @activityInProgress.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get activityInProgress;

  /// No description provided for @activityFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get activityFree;

  /// No description provided for @activityCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get activityCash;

  /// No description provided for @activityPointsReward.
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get activityPointsReward;

  /// No description provided for @activityCashAndPoints.
  ///
  /// In en, this message translates to:
  /// **'Cash + Points'**
  String get activityCashAndPoints;

  /// No description provided for @activityInfo.
  ///
  /// In en, this message translates to:
  /// **'Activity Info'**
  String get activityInfo;

  /// No description provided for @activityPublisher.
  ///
  /// In en, this message translates to:
  /// **'Publisher'**
  String get activityPublisher;

  /// No description provided for @activityViewExpertProfileShort.
  ///
  /// In en, this message translates to:
  /// **'View Expert Profile'**
  String get activityViewExpertProfileShort;

  /// No description provided for @activityParticipantsCount.
  ///
  /// In en, this message translates to:
  /// **'Participants'**
  String get activityParticipantsCount;

  /// No description provided for @activityStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get activityStatusLabel;

  /// No description provided for @activityRegistrationDeadline.
  ///
  /// In en, this message translates to:
  /// **'Registration deadline: '**
  String get activityRegistrationDeadline;

  /// No description provided for @activityCurrentApplicants.
  ///
  /// In en, this message translates to:
  /// **'Current applicants: '**
  String get activityCurrentApplicants;

  /// No description provided for @activityJoinLottery.
  ///
  /// In en, this message translates to:
  /// **'Join Lottery'**
  String get activityJoinLottery;

  /// No description provided for @activityAlreadyRegistered.
  ///
  /// In en, this message translates to:
  /// **'Registered'**
  String get activityAlreadyRegistered;

  /// No description provided for @activityNoWinners.
  ///
  /// In en, this message translates to:
  /// **'No winners yet'**
  String get activityNoWinners;

  /// No description provided for @activityWinnerList.
  ///
  /// In en, this message translates to:
  /// **'Winner List'**
  String get activityWinnerList;

  /// No description provided for @activityPrizePoints.
  ///
  /// In en, this message translates to:
  /// **'Points Reward'**
  String get activityPrizePoints;

  /// No description provided for @activityPrizePhysical.
  ///
  /// In en, this message translates to:
  /// **'Physical Prize'**
  String get activityPrizePhysical;

  /// No description provided for @activityPrizeVoucher.
  ///
  /// In en, this message translates to:
  /// **'Voucher Code'**
  String get activityPrizeVoucher;

  /// No description provided for @activityPrizeInPerson.
  ///
  /// In en, this message translates to:
  /// **'In-Person Event'**
  String get activityPrizeInPerson;

  /// No description provided for @activityPrize.
  ///
  /// In en, this message translates to:
  /// **'Prize'**
  String get activityPrize;

  /// No description provided for @activityPrizeCount.
  ///
  /// In en, this message translates to:
  /// **'Prize Slots: {count}'**
  String activityPrizeCount(Object count);

  /// No description provided for @activityYouWon.
  ///
  /// In en, this message translates to:
  /// **'Congratulations! You Won!'**
  String get activityYouWon;

  /// No description provided for @activityYouWonVoucher.
  ///
  /// In en, this message translates to:
  /// **'Your voucher code: {code}'**
  String activityYouWonVoucher(Object code);

  /// No description provided for @activityNotWon.
  ///
  /// In en, this message translates to:
  /// **'Stay Tuned for Next Event'**
  String get activityNotWon;

  /// No description provided for @activityDrawCompleted.
  ///
  /// In en, this message translates to:
  /// **'Draw Completed'**
  String get activityDrawCompleted;

  /// No description provided for @activityLotteryPending.
  ///
  /// In en, this message translates to:
  /// **'Awaiting Draw'**
  String get activityLotteryPending;

  /// No description provided for @activityPersonCount.
  ///
  /// In en, this message translates to:
  /// **'{current}/{max}'**
  String activityPersonCount(int current, int max);

  /// No description provided for @leaderboardNoLeaderboards.
  ///
  /// In en, this message translates to:
  /// **'No leaderboards'**
  String get leaderboardNoLeaderboards;

  /// No description provided for @leaderboardNoLeaderboardsMessage.
  ///
  /// In en, this message translates to:
  /// **'No leaderboards available'**
  String get leaderboardNoLeaderboardsMessage;

  /// No description provided for @leaderboardNoCompetitorsHint.
  ///
  /// In en, this message translates to:
  /// **'No competitors yet. Tap below to submit the first one!'**
  String get leaderboardNoCompetitorsHint;

  /// No description provided for @leaderboardNetVotesCount.
  ///
  /// In en, this message translates to:
  /// **'Net {count}'**
  String leaderboardNetVotesCount(int count);

  /// No description provided for @leaderboardRankFirst.
  ///
  /// In en, this message translates to:
  /// **'#1'**
  String get leaderboardRankFirst;

  /// No description provided for @leaderboardRankSecond.
  ///
  /// In en, this message translates to:
  /// **'#2'**
  String get leaderboardRankSecond;

  /// No description provided for @leaderboardRankThird.
  ///
  /// In en, this message translates to:
  /// **'#3'**
  String get leaderboardRankThird;

  /// No description provided for @leaderboardDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get leaderboardDetails;

  /// No description provided for @leaderboardCompletedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} completed'**
  String leaderboardCompletedCount(int count);

  /// No description provided for @notificationSystemNotifications.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get notificationSystemNotifications;

  /// No description provided for @notificationInteractionMessages.
  ///
  /// In en, this message translates to:
  /// **'Interactions'**
  String get notificationInteractionMessages;

  /// No description provided for @notificationNoTaskChatDesc.
  ///
  /// In en, this message translates to:
  /// **'Accept or post a task to start chatting'**
  String get notificationNoTaskChatDesc;

  /// No description provided for @taskExpertDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Expert Details'**
  String get taskExpertDetailTitle;

  /// No description provided for @taskExpertExpertNotExist.
  ///
  /// In en, this message translates to:
  /// **'Expert not found'**
  String get taskExpertExpertNotExist;

  /// No description provided for @taskExpertExpertNotExistDesc.
  ///
  /// In en, this message translates to:
  /// **'This expert does not exist or has been removed'**
  String get taskExpertExpertNotExistDesc;

  /// No description provided for @taskExpertBio.
  ///
  /// In en, this message translates to:
  /// **'Bio'**
  String get taskExpertBio;

  /// No description provided for @taskExpertSpecialties.
  ///
  /// In en, this message translates to:
  /// **'Specialties'**
  String get taskExpertSpecialties;

  /// No description provided for @taskExpertProvidedServices.
  ///
  /// In en, this message translates to:
  /// **'Services Provided'**
  String get taskExpertProvidedServices;

  /// No description provided for @taskExpertNoServicesDesc.
  ///
  /// In en, this message translates to:
  /// **'This expert hasn\'t listed any services yet'**
  String get taskExpertNoServicesDesc;

  /// No description provided for @taskExpertAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get taskExpertAccepted;

  /// No description provided for @taskExpertRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get taskExpertRejected;

  /// No description provided for @taskExpertAppliedStatus.
  ///
  /// In en, this message translates to:
  /// **'Applied'**
  String get taskExpertAppliedStatus;

  /// No description provided for @taskExpertApplicationPending.
  ///
  /// In en, this message translates to:
  /// **'Your expert application is under review'**
  String get taskExpertApplicationPending;

  /// No description provided for @taskExpertApplicationApproved.
  ///
  /// In en, this message translates to:
  /// **'Your expert application has been approved!'**
  String get taskExpertApplicationApproved;

  /// No description provided for @taskExpertApplicationRejected.
  ///
  /// In en, this message translates to:
  /// **'Your expert application was not approved'**
  String get taskExpertApplicationRejected;

  /// No description provided for @taskExpertServiceCount.
  ///
  /// In en, this message translates to:
  /// **'{count} services'**
  String taskExpertServiceCount(int count);

  /// No description provided for @taskExpertShareTitle.
  ///
  /// In en, this message translates to:
  /// **'Share Expert - {name}'**
  String taskExpertShareTitle(String name);

  /// No description provided for @taskExpertShareText.
  ///
  /// In en, this message translates to:
  /// **'Check out this expert: {name}'**
  String taskExpertShareText(String name);

  /// No description provided for @infoFAQAccountQ1.
  ///
  /// In en, this message translates to:
  /// **'How do I register an account?'**
  String get infoFAQAccountQ1;

  /// No description provided for @infoFAQAccountA1.
  ///
  /// In en, this message translates to:
  /// **'You can register using your email address or phone number. Click \'Register\' on the login page and follow the instructions.'**
  String get infoFAQAccountA1;

  /// No description provided for @infoFAQAccountQ2.
  ///
  /// In en, this message translates to:
  /// **'How do I reset my password?'**
  String get infoFAQAccountQ2;

  /// No description provided for @infoFAQAccountA2.
  ///
  /// In en, this message translates to:
  /// **'Click \'Forgot Password\' on the login page, enter your registered email and follow the verification steps to reset it.'**
  String get infoFAQAccountA2;

  /// No description provided for @infoFAQAccountQ3.
  ///
  /// In en, this message translates to:
  /// **'How do I edit my profile?'**
  String get infoFAQAccountQ3;

  /// No description provided for @infoFAQAccountA3.
  ///
  /// In en, this message translates to:
  /// **'Go to Profile > Edit Profile to update your avatar, nickname, bio and other information.'**
  String get infoFAQAccountA3;

  /// No description provided for @infoFAQAccountQ4.
  ///
  /// In en, this message translates to:
  /// **'How do I delete my account?'**
  String get infoFAQAccountQ4;

  /// No description provided for @infoFAQAccountA4.
  ///
  /// In en, this message translates to:
  /// **'Go to Settings > Account Security > Delete Account. Please note this action is irreversible.'**
  String get infoFAQAccountA4;

  /// No description provided for @infoFAQTaskQ1.
  ///
  /// In en, this message translates to:
  /// **'How do I publish a task?'**
  String get infoFAQTaskQ1;

  /// No description provided for @infoFAQTaskA1.
  ///
  /// In en, this message translates to:
  /// **'Tap the \'+\' button at the bottom of the screen, select \'Publish Task\', fill in the details and submit.'**
  String get infoFAQTaskA1;

  /// No description provided for @infoFAQTaskQ2.
  ///
  /// In en, this message translates to:
  /// **'How do I accept a task?'**
  String get infoFAQTaskQ2;

  /// No description provided for @infoFAQTaskA2.
  ///
  /// In en, this message translates to:
  /// **'Browse available tasks, tap on one to view details, then click \'Accept Task\' to start.'**
  String get infoFAQTaskA2;

  /// No description provided for @infoFAQTaskQ3.
  ///
  /// In en, this message translates to:
  /// **'How do I cancel a task?'**
  String get infoFAQTaskQ3;

  /// No description provided for @infoFAQTaskA3.
  ///
  /// In en, this message translates to:
  /// **'Go to the task detail page and click \'Cancel Task\'. Please note that cancellation policies may apply.'**
  String get infoFAQTaskA3;

  /// No description provided for @infoFAQTaskQ4.
  ///
  /// In en, this message translates to:
  /// **'What if there is a dispute?'**
  String get infoFAQTaskQ4;

  /// No description provided for @infoFAQTaskA4.
  ///
  /// In en, this message translates to:
  /// **'You can raise a dispute via the task chat page. Our customer service team will assist in resolving it.'**
  String get infoFAQTaskA4;

  /// No description provided for @infoFAQPaymentQ1.
  ///
  /// In en, this message translates to:
  /// **'What payment methods are supported?'**
  String get infoFAQPaymentQ1;

  /// No description provided for @infoFAQPaymentA1.
  ///
  /// In en, this message translates to:
  /// **'We support Stripe (credit/debit cards), Apple Pay, and WeChat Pay.'**
  String get infoFAQPaymentA1;

  /// No description provided for @infoFAQPaymentQ2.
  ///
  /// In en, this message translates to:
  /// **'How does the escrow system work?'**
  String get infoFAQPaymentQ2;

  /// No description provided for @infoFAQPaymentA2.
  ///
  /// In en, this message translates to:
  /// **'When you pay for a task, the funds are held securely. The helper receives payment only after you confirm task completion.'**
  String get infoFAQPaymentA2;

  /// No description provided for @infoFAQPaymentQ3.
  ///
  /// In en, this message translates to:
  /// **'How do I request a refund?'**
  String get infoFAQPaymentQ3;

  /// No description provided for @infoFAQPaymentA3.
  ///
  /// In en, this message translates to:
  /// **'Go to the task detail page and click \'Request Refund\'. Provide a reason and our team will review it within 1-3 business days.'**
  String get infoFAQPaymentA3;

  /// No description provided for @infoFAQPaymentQ4.
  ///
  /// In en, this message translates to:
  /// **'How do I withdraw my earnings?'**
  String get infoFAQPaymentQ4;

  /// No description provided for @infoFAQPaymentA4.
  ///
  /// In en, this message translates to:
  /// **'Go to Wallet > Withdraw, connect your Stripe account and withdraw to your bank account.'**
  String get infoFAQPaymentA4;

  /// No description provided for @vipPlanFeatureMonthly1.
  ///
  /// In en, this message translates to:
  /// **'Priority task recommendation'**
  String get vipPlanFeatureMonthly1;

  /// No description provided for @vipPlanFeatureMonthly2.
  ///
  /// In en, this message translates to:
  /// **'Exclusive VIP badge'**
  String get vipPlanFeatureMonthly2;

  /// No description provided for @vipPlanFeatureMonthly3.
  ///
  /// In en, this message translates to:
  /// **'Reduced service fees'**
  String get vipPlanFeatureMonthly3;

  /// No description provided for @vipPlanFeatureYearly1.
  ///
  /// In en, this message translates to:
  /// **'All monthly benefits'**
  String get vipPlanFeatureYearly1;

  /// No description provided for @vipPlanFeatureYearly2.
  ///
  /// In en, this message translates to:
  /// **'Dedicated customer support'**
  String get vipPlanFeatureYearly2;

  /// No description provided for @vipPlanFeatureYearly3.
  ///
  /// In en, this message translates to:
  /// **'Points boost & exclusive activities'**
  String get vipPlanFeatureYearly3;

  /// No description provided for @vipPlanFeatureYearly4.
  ///
  /// In en, this message translates to:
  /// **'Data analytics dashboard'**
  String get vipPlanFeatureYearly4;

  /// No description provided for @vipPlanBadgeBestValue.
  ///
  /// In en, this message translates to:
  /// **'Best Value'**
  String get vipPlanBadgeBestValue;

  /// No description provided for @vipRegularUser.
  ///
  /// In en, this message translates to:
  /// **'Regular User'**
  String get vipRegularUser;

  /// No description provided for @infoVersionFormat.
  ///
  /// In en, this message translates to:
  /// **'Version {version} ({buildNumber})'**
  String infoVersionFormat(String version, String buildNumber);

  /// No description provided for @infoCopyright.
  ///
  /// In en, this message translates to:
  /// **'© 2024 Link²Ur. All rights reserved.'**
  String get infoCopyright;

  /// No description provided for @chatImagePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'[Image]'**
  String get chatImagePlaceholder;

  /// No description provided for @studentVerificationEmailLocked.
  ///
  /// In en, this message translates to:
  /// **'Email is locked, please wait for review to complete'**
  String get studentVerificationEmailLocked;

  /// No description provided for @studentVerificationPending.
  ///
  /// In en, this message translates to:
  /// **'Verification under review, please check your email and complete verification'**
  String get studentVerificationPending;

  /// No description provided for @purchaseFailed.
  ///
  /// In en, this message translates to:
  /// **'Purchase failed, please try again later.'**
  String get purchaseFailed;

  /// No description provided for @restorePurchaseFailed.
  ///
  /// In en, this message translates to:
  /// **'Restore purchase failed, please try again later.'**
  String get restorePurchaseFailed;

  /// No description provided for @onboardingTaskTypeErrand.
  ///
  /// In en, this message translates to:
  /// **'Errand Running'**
  String get onboardingTaskTypeErrand;

  /// No description provided for @onboardingTaskTypeSkill.
  ///
  /// In en, this message translates to:
  /// **'Skill Service'**
  String get onboardingTaskTypeSkill;

  /// No description provided for @onboardingTaskTypeHousekeeping.
  ///
  /// In en, this message translates to:
  /// **'Housekeeping'**
  String get onboardingTaskTypeHousekeeping;

  /// No description provided for @onboardingTaskTypeTransport.
  ///
  /// In en, this message translates to:
  /// **'Transportation'**
  String get onboardingTaskTypeTransport;

  /// No description provided for @onboardingTaskTypeSocial.
  ///
  /// In en, this message translates to:
  /// **'Social Help'**
  String get onboardingTaskTypeSocial;

  /// No description provided for @onboardingTaskTypeCampus.
  ///
  /// In en, this message translates to:
  /// **'Campus Life'**
  String get onboardingTaskTypeCampus;

  /// No description provided for @onboardingTaskTypeSecondhand.
  ///
  /// In en, this message translates to:
  /// **'Secondhand & Rental'**
  String get onboardingTaskTypeSecondhand;

  /// No description provided for @onboardingTaskTypePetCare.
  ///
  /// In en, this message translates to:
  /// **'Pet Care'**
  String get onboardingTaskTypePetCare;

  /// No description provided for @onboardingTaskTypeConvenience.
  ///
  /// In en, this message translates to:
  /// **'Life Convenience'**
  String get onboardingTaskTypeConvenience;

  /// No description provided for @onboardingTaskTypeOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get onboardingTaskTypeOther;

  /// No description provided for @fleaMarketCategoryKeyElectronics.
  ///
  /// In en, this message translates to:
  /// **'electronics'**
  String get fleaMarketCategoryKeyElectronics;

  /// No description provided for @fleaMarketCategoryKeyBooks.
  ///
  /// In en, this message translates to:
  /// **'books'**
  String get fleaMarketCategoryKeyBooks;

  /// No description provided for @fleaMarketCategoryKeyDaily.
  ///
  /// In en, this message translates to:
  /// **'daily'**
  String get fleaMarketCategoryKeyDaily;

  /// No description provided for @fleaMarketCategoryKeyClothing.
  ///
  /// In en, this message translates to:
  /// **'clothing'**
  String get fleaMarketCategoryKeyClothing;

  /// No description provided for @fleaMarketCategoryKeySports.
  ///
  /// In en, this message translates to:
  /// **'sports'**
  String get fleaMarketCategoryKeySports;

  /// No description provided for @fleaMarketCategoryKeyOther.
  ///
  /// In en, this message translates to:
  /// **'other'**
  String get fleaMarketCategoryKeyOther;

  /// No description provided for @couponRewardPoints50.
  ///
  /// In en, this message translates to:
  /// **'+50 Points'**
  String get couponRewardPoints50;

  /// No description provided for @couponRewardPoints100Coupon.
  ///
  /// In en, this message translates to:
  /// **'+100 Points + Coupon'**
  String get couponRewardPoints100Coupon;

  /// No description provided for @couponRewardPoints500Vip.
  ///
  /// In en, this message translates to:
  /// **'+500 Points + VIP Trial'**
  String get couponRewardPoints500Vip;

  /// No description provided for @settingsLanguageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// No description provided for @settingsLanguageChinese.
  ///
  /// In en, this message translates to:
  /// **'中文'**
  String get settingsLanguageChinese;

  /// No description provided for @infoTermsContent.
  ///
  /// In en, this message translates to:
  /// **'Link²Ur Terms of Service\n\nLast updated: January 1, 2024\n\n1. Service Overview\nLink²Ur is a campus mutual-aid platform designed to help users publish and accept various life service tasks.\n\n2. User Responsibilities\n- Users must provide truthful and accurate personal information\n- Users must comply with platform rules and applicable laws\n- Users are responsible for the content they publish\n\n3. Platform Responsibilities\n- The platform provides information intermediary services\n- The platform implements escrow protection for transaction funds\n- The platform reserves the right to take action against violations\n\n4. Payment & Settlement\n- All payments are processed through third-party payment platforms\n- Tasks are automatically settled upon completion\n- The platform charges reasonable service fees\n\n5. Privacy Protection\nPlease refer to our Privacy Policy for detailed information.\n\n6. Disclaimer\nAs an information intermediary, the platform does not bear direct responsibility for transactions between users.\n\nIf you have any questions, please contact our customer service team.'**
  String get infoTermsContent;

  /// No description provided for @infoPrivacyContent.
  ///
  /// In en, this message translates to:
  /// **'Link²Ur Privacy Policy\n\nLast updated: January 1, 2024\n\n1. Information Collection\nWe collect the following types of information:\n- Registration information (name, email, etc.)\n- Location information (for nearby task recommendations)\n- Device information (for push notifications)\n\n2. Information Usage\nWe use your information to:\n- Provide and improve services\n- Personalized recommendations\n- Ensure transaction security\n\n3. Information Storage & Protection\n- Data is stored on secure servers\n- Encryption technology is used to protect data transmission\n- Regular security audits are conducted\n\n4. Information Sharing\nWe do not sell your personal information. We only share in the following cases:\n- With your consent\n- Legal requirements\n- Necessary for service provision\n\n5. Cookie Policy\nWe use cookies to improve user experience.\n\n6. Your Rights\n- Access and modify personal information\n- Delete account\n- Unsubscribe from notifications\n\nFor privacy-related questions, please contact privacy@link2ur.com'**
  String get infoPrivacyContent;

  /// No description provided for @infoCookieContent.
  ///
  /// In en, this message translates to:
  /// **'Link²Ur Cookie Policy\n\nWe use cookies and similar technologies to improve your experience.\n\n1. What are Cookies\nCookies are small text files stored on your device.\n\n2. How We Use Cookies\n- Essential Cookies: Maintain login status\n- Functional Cookies: Remember preferences\n- Analytics Cookies: Improve service quality\n\n3. Managing Cookies\nYou can manage cookie preferences in your device settings.'**
  String get infoCookieContent;

  /// No description provided for @serviceNegotiatePrice.
  ///
  /// In en, this message translates to:
  /// **'Price Negotiation'**
  String get serviceNegotiatePrice;

  /// No description provided for @serviceNegotiatePriceHint.
  ///
  /// In en, this message translates to:
  /// **'Propose a different price to the expert'**
  String get serviceNegotiatePriceHint;

  /// No description provided for @serviceSelectDeadline.
  ///
  /// In en, this message translates to:
  /// **'Select Deadline'**
  String get serviceSelectDeadline;

  /// No description provided for @serviceApplyOtherSlot.
  ///
  /// In en, this message translates to:
  /// **'Apply for Another Slot'**
  String get serviceApplyOtherSlot;

  /// No description provided for @publishTitle.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get publishTitle;

  /// No description provided for @publishTypeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose what you want to publish'**
  String get publishTypeSubtitle;

  /// No description provided for @publishTaskTab.
  ///
  /// In en, this message translates to:
  /// **'Post Task'**
  String get publishTaskTab;

  /// No description provided for @publishFleaMarketTab.
  ///
  /// In en, this message translates to:
  /// **'Sell Item'**
  String get publishFleaMarketTab;

  /// No description provided for @publishPostTab.
  ///
  /// In en, this message translates to:
  /// **'Forum Post'**
  String get publishPostTab;

  /// No description provided for @publishTaskCardLabel.
  ///
  /// In en, this message translates to:
  /// **'Post Task'**
  String get publishTaskCardLabel;

  /// No description provided for @publishFleaCardLabel.
  ///
  /// In en, this message translates to:
  /// **'Sell Item'**
  String get publishFleaCardLabel;

  /// No description provided for @publishPostCardLabel.
  ///
  /// In en, this message translates to:
  /// **'Forum Post'**
  String get publishPostCardLabel;

  /// No description provided for @publishRelatedContent.
  ///
  /// In en, this message translates to:
  /// **'Related Content'**
  String get publishRelatedContent;

  /// No description provided for @publishSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search services, activities, items, leaderboards...'**
  String get publishSearchHint;

  /// No description provided for @publishRelatedToMe.
  ///
  /// In en, this message translates to:
  /// **'Related to me'**
  String get publishRelatedToMe;

  /// No description provided for @publishSearchResults.
  ///
  /// In en, this message translates to:
  /// **'Search results'**
  String get publishSearchResults;

  /// No description provided for @publishNoResultsTryKeywords.
  ///
  /// In en, this message translates to:
  /// **'No results, try other keywords'**
  String get publishNoResultsTryKeywords;

  /// No description provided for @publishSearchAndLink.
  ///
  /// In en, this message translates to:
  /// **'Search and link'**
  String get publishSearchAndLink;

  /// No description provided for @publishRecentSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent Publishes'**
  String get publishRecentSectionTitle;

  /// No description provided for @publishTipsSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Publish Tips'**
  String get publishTipsSectionTitle;

  /// No description provided for @publishRecentEmpty.
  ///
  /// In en, this message translates to:
  /// **'No recent publishes'**
  String get publishRecentEmpty;

  /// No description provided for @publishTip1.
  ///
  /// In en, this message translates to:
  /// **'Clear, specific titles get more visibility'**
  String get publishTip1;

  /// No description provided for @publishTip2.
  ///
  /// In en, this message translates to:
  /// **'Clear photos increase views and sales'**
  String get publishTip2;

  /// No description provided for @publishTip3.
  ///
  /// In en, this message translates to:
  /// **'State reward or price upfront to save time'**
  String get publishTip3;

  /// No description provided for @publishTip4.
  ///
  /// In en, this message translates to:
  /// **'Pick the right category for better exposure'**
  String get publishTip4;

  /// No description provided for @profileUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Update failed'**
  String get profileUpdateFailed;

  /// No description provided for @profileAvatarUpdated.
  ///
  /// In en, this message translates to:
  /// **'Avatar updated'**
  String get profileAvatarUpdated;

  /// No description provided for @profileUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed'**
  String get profileUploadFailed;

  /// No description provided for @profilePreferencesUpdated.
  ///
  /// In en, this message translates to:
  /// **'Preferences updated'**
  String get profilePreferencesUpdated;

  /// No description provided for @commonSuccess.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get commonSuccess;

  /// No description provided for @commonError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get commonError;

  /// No description provided for @commonSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get commonSaved;

  /// No description provided for @validatorEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter email address'**
  String get validatorEmailRequired;

  /// No description provided for @validatorEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address'**
  String get validatorEmailInvalid;

  /// No description provided for @validatorPhoneRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter phone number'**
  String get validatorPhoneRequired;

  /// No description provided for @validatorPhoneInvalid.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid phone number'**
  String get validatorPhoneInvalid;

  /// No description provided for @validatorUKPhoneRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your phone number'**
  String get validatorUKPhoneRequired;

  /// No description provided for @validatorUKPhoneInvalid.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid UK mobile number'**
  String get validatorUKPhoneInvalid;

  /// No description provided for @validatorPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter password'**
  String get validatorPasswordRequired;

  /// No description provided for @validatorPasswordMinLength.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters'**
  String get validatorPasswordMinLength;

  /// No description provided for @validatorPasswordFormat.
  ///
  /// In en, this message translates to:
  /// **'Password must contain both letters and numbers'**
  String get validatorPasswordFormat;

  /// No description provided for @validatorConfirmPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Please confirm password'**
  String get validatorConfirmPasswordRequired;

  /// No description provided for @validatorPasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get validatorPasswordMismatch;

  /// No description provided for @validatorCodeRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter verification code'**
  String get validatorCodeRequired;

  /// No description provided for @validatorCodeLength.
  ///
  /// In en, this message translates to:
  /// **'Verification code must be {length} digits'**
  String validatorCodeLength(int length);

  /// No description provided for @validatorCodeDigitsOnly.
  ///
  /// In en, this message translates to:
  /// **'Verification code must contain only digits'**
  String get validatorCodeDigitsOnly;

  /// No description provided for @validatorUsernameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter username'**
  String get validatorUsernameRequired;

  /// No description provided for @validatorUsernameMinLength.
  ///
  /// In en, this message translates to:
  /// **'Username must be at least 2 characters'**
  String get validatorUsernameMinLength;

  /// No description provided for @validatorUsernameMaxLength.
  ///
  /// In en, this message translates to:
  /// **'Username must be at most 20 characters'**
  String get validatorUsernameMaxLength;

  /// No description provided for @validatorTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter title'**
  String get validatorTitleRequired;

  /// No description provided for @validatorTitleMaxLength.
  ///
  /// In en, this message translates to:
  /// **'Title must be at most {maxLength} characters'**
  String validatorTitleMaxLength(int maxLength);

  /// No description provided for @validatorDescriptionRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter description'**
  String get validatorDescriptionRequired;

  /// No description provided for @validatorDescriptionMaxLength.
  ///
  /// In en, this message translates to:
  /// **'Description must be at most {maxLength} characters'**
  String validatorDescriptionMaxLength(int maxLength);

  /// No description provided for @validatorAmountRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter amount'**
  String get validatorAmountRequired;

  /// No description provided for @validatorAmountInvalid.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid amount'**
  String get validatorAmountInvalid;

  /// No description provided for @validatorAmountPositive.
  ///
  /// In en, this message translates to:
  /// **'Amount must be greater than 0'**
  String get validatorAmountPositive;

  /// No description provided for @validatorAmountMin.
  ///
  /// In en, this message translates to:
  /// **'Amount cannot be less than {min}'**
  String validatorAmountMin(double min);

  /// No description provided for @validatorAmountMax.
  ///
  /// In en, this message translates to:
  /// **'Amount cannot be greater than {max}'**
  String validatorAmountMax(double max);

  /// No description provided for @validatorUrlRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter URL'**
  String get validatorUrlRequired;

  /// No description provided for @validatorUrlInvalid.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid URL'**
  String get validatorUrlInvalid;

  /// No description provided for @validatorFieldRequired.
  ///
  /// In en, this message translates to:
  /// **'{fieldName} is required'**
  String validatorFieldRequired(String fieldName);

  /// No description provided for @validatorFieldMinLength.
  ///
  /// In en, this message translates to:
  /// **'{fieldName} must be at least {min} characters'**
  String validatorFieldMinLength(String fieldName, int min);

  /// No description provided for @validatorFieldMaxLength.
  ///
  /// In en, this message translates to:
  /// **'{fieldName} must be at most {max} characters'**
  String validatorFieldMaxLength(String fieldName, int max);

  /// No description provided for @timeYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get timeYesterday;

  /// No description provided for @timeDayBeforeYesterday.
  ///
  /// In en, this message translates to:
  /// **'Day before yesterday'**
  String get timeDayBeforeYesterday;

  /// No description provided for @timeDeadlineMinutes.
  ///
  /// In en, this message translates to:
  /// **'Due in {minutes} min'**
  String timeDeadlineMinutes(int minutes);

  /// No description provided for @timeDeadlineHours.
  ///
  /// In en, this message translates to:
  /// **'Due in {hours} hr'**
  String timeDeadlineHours(int hours);

  /// No description provided for @timeDeadlineDays.
  ///
  /// In en, this message translates to:
  /// **'Due in {days} days'**
  String timeDeadlineDays(int days);

  /// No description provided for @timeDeadlineDate.
  ///
  /// In en, this message translates to:
  /// **'Due {date}'**
  String timeDeadlineDate(String date);

  /// No description provided for @badgeVip.
  ///
  /// In en, this message translates to:
  /// **'VIP'**
  String get badgeVip;

  /// No description provided for @badgeSuper.
  ///
  /// In en, this message translates to:
  /// **'Super'**
  String get badgeSuper;

  /// No description provided for @notificationPermTitle.
  ///
  /// In en, this message translates to:
  /// **'Enable Push Notifications'**
  String get notificationPermTitle;

  /// No description provided for @notificationPermDesc.
  ///
  /// In en, this message translates to:
  /// **'Stay updated with:\n\n• Task status updates\n• New message alerts\n• Task match recommendations\n• Deals & promotions'**
  String get notificationPermDesc;

  /// No description provided for @notificationPermEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable Notifications'**
  String get notificationPermEnable;

  /// No description provided for @notificationPermSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip for Now'**
  String get notificationPermSkip;

  /// No description provided for @notificationPermSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification Permission Required'**
  String get notificationPermSettingsTitle;

  /// No description provided for @notificationPermSettingsDesc.
  ///
  /// In en, this message translates to:
  /// **'You have denied notification permission. Please enable it manually in system settings.'**
  String get notificationPermSettingsDesc;

  /// No description provided for @notificationPermSettingsLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get notificationPermSettingsLater;

  /// No description provided for @notificationPermSettingsGo.
  ///
  /// In en, this message translates to:
  /// **'Go to Settings'**
  String get notificationPermSettingsGo;

  /// No description provided for @shareTitle.
  ///
  /// In en, this message translates to:
  /// **'Share to'**
  String get shareTitle;

  /// No description provided for @shareLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get shareLinkCopied;

  /// No description provided for @shareQQ.
  ///
  /// In en, this message translates to:
  /// **'QQ'**
  String get shareQQ;

  /// No description provided for @shareMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get shareMore;

  /// No description provided for @actionItemPublished.
  ///
  /// In en, this message translates to:
  /// **'Item published'**
  String get actionItemPublished;

  /// No description provided for @actionPublishFailed.
  ///
  /// In en, this message translates to:
  /// **'Publish failed'**
  String get actionPublishFailed;

  /// No description provided for @actionPurchaseSuccess.
  ///
  /// In en, this message translates to:
  /// **'Purchase successful'**
  String get actionPurchaseSuccess;

  /// No description provided for @actionPurchaseFailed.
  ///
  /// In en, this message translates to:
  /// **'Purchase failed'**
  String get actionPurchaseFailed;

  /// No description provided for @actionItemUpdated.
  ///
  /// In en, this message translates to:
  /// **'Item updated'**
  String get actionItemUpdated;

  /// No description provided for @actionUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Update failed'**
  String get actionUpdateFailed;

  /// No description provided for @actionRefreshSuccess.
  ///
  /// In en, this message translates to:
  /// **'Refreshed'**
  String get actionRefreshSuccess;

  /// No description provided for @actionRefreshFailed.
  ///
  /// In en, this message translates to:
  /// **'Refresh failed'**
  String get actionRefreshFailed;

  /// No description provided for @actionApplicationSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Application submitted'**
  String get actionApplicationSubmitted;

  /// No description provided for @actionApplicationFailed.
  ///
  /// In en, this message translates to:
  /// **'Application failed'**
  String get actionApplicationFailed;

  /// No description provided for @actionApplicationCancelled.
  ///
  /// In en, this message translates to:
  /// **'Application cancelled'**
  String get actionApplicationCancelled;

  /// No description provided for @actionCancelFailed.
  ///
  /// In en, this message translates to:
  /// **'Cancel failed'**
  String get actionCancelFailed;

  /// No description provided for @actionApplicationAccepted.
  ///
  /// In en, this message translates to:
  /// **'Application accepted'**
  String get actionApplicationAccepted;

  /// No description provided for @actionApplicationRejected.
  ///
  /// In en, this message translates to:
  /// **'Application rejected'**
  String get actionApplicationRejected;

  /// No description provided for @actionOperationFailed.
  ///
  /// In en, this message translates to:
  /// **'Operation failed'**
  String get actionOperationFailed;

  /// No description provided for @actionTaskCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completion submitted'**
  String get actionTaskCompleted;

  /// No description provided for @actionSubmitFailed.
  ///
  /// In en, this message translates to:
  /// **'Submit failed'**
  String get actionSubmitFailed;

  /// No description provided for @actionCompletionConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Completion confirmed'**
  String get actionCompletionConfirmed;

  /// No description provided for @actionConfirmFailed.
  ///
  /// In en, this message translates to:
  /// **'Confirm failed'**
  String get actionConfirmFailed;

  /// No description provided for @actionTaskCancelled.
  ///
  /// In en, this message translates to:
  /// **'Task cancelled'**
  String get actionTaskCancelled;

  /// No description provided for @actionReviewSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Review submitted'**
  String get actionReviewSubmitted;

  /// No description provided for @actionReviewFailed.
  ///
  /// In en, this message translates to:
  /// **'Review failed'**
  String get actionReviewFailed;

  /// No description provided for @actionRefundSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Refund request submitted'**
  String get actionRefundSubmitted;

  /// No description provided for @actionRefundFailed.
  ///
  /// In en, this message translates to:
  /// **'Refund request failed'**
  String get actionRefundFailed;

  /// No description provided for @actionRefundRevoked.
  ///
  /// In en, this message translates to:
  /// **'Refund request revoked'**
  String get actionRefundRevoked;

  /// No description provided for @actionRevokeFailed.
  ///
  /// In en, this message translates to:
  /// **'Revoke failed'**
  String get actionRevokeFailed;

  /// No description provided for @actionDisputeSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Dispute submitted'**
  String get actionDisputeSubmitted;

  /// No description provided for @actionDisputeFailed.
  ///
  /// In en, this message translates to:
  /// **'Dispute submission failed'**
  String get actionDisputeFailed;

  /// No description provided for @actionCheckInSuccess.
  ///
  /// In en, this message translates to:
  /// **'Check-in successful!'**
  String get actionCheckInSuccess;

  /// No description provided for @actionCheckInFailed.
  ///
  /// In en, this message translates to:
  /// **'Check-in failed'**
  String get actionCheckInFailed;

  /// No description provided for @actionVoteFailed.
  ///
  /// In en, this message translates to:
  /// **'Vote failed'**
  String get actionVoteFailed;

  /// No description provided for @actionLeaderboardApplied.
  ///
  /// In en, this message translates to:
  /// **'Application submitted'**
  String get actionLeaderboardApplied;

  /// No description provided for @actionLeaderboardSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Submitted successfully'**
  String get actionLeaderboardSubmitted;

  /// No description provided for @actionVerificationSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Submitted, please check your email for verification'**
  String get actionVerificationSubmitted;

  /// No description provided for @actionVerificationSuccess.
  ///
  /// In en, this message translates to:
  /// **'Verification successful'**
  String get actionVerificationSuccess;

  /// No description provided for @actionVerificationFailed.
  ///
  /// In en, this message translates to:
  /// **'Verification failed'**
  String get actionVerificationFailed;

  /// No description provided for @actionRenewalSuccess.
  ///
  /// In en, this message translates to:
  /// **'Renewal successful'**
  String get actionRenewalSuccess;

  /// No description provided for @actionRenewalFailed.
  ///
  /// In en, this message translates to:
  /// **'Renewal failed'**
  String get actionRenewalFailed;

  /// No description provided for @actionRegistrationSuccess.
  ///
  /// In en, this message translates to:
  /// **'Registration successful'**
  String get actionRegistrationSuccess;

  /// No description provided for @actionRegistrationFailed.
  ///
  /// In en, this message translates to:
  /// **'Registration failed'**
  String get actionRegistrationFailed;

  /// No description provided for @actionConversationEnded.
  ///
  /// In en, this message translates to:
  /// **'Conversation ended'**
  String get actionConversationEnded;

  /// No description provided for @actionEndConversationFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to end conversation'**
  String get actionEndConversationFailed;

  /// No description provided for @actionFeedbackSuccess.
  ///
  /// In en, this message translates to:
  /// **'Thank you for your feedback'**
  String get actionFeedbackSuccess;

  /// No description provided for @actionFeedbackFailed.
  ///
  /// In en, this message translates to:
  /// **'Feedback failed'**
  String get actionFeedbackFailed;

  /// No description provided for @actionCouponClaimed.
  ///
  /// In en, this message translates to:
  /// **'Coupon claimed'**
  String get actionCouponClaimed;

  /// No description provided for @actionCouponRedeemed.
  ///
  /// In en, this message translates to:
  /// **'Redeemed successfully'**
  String get actionCouponRedeemed;

  /// No description provided for @actionInviteCodeUsed.
  ///
  /// In en, this message translates to:
  /// **'Invite code applied'**
  String get actionInviteCodeUsed;

  /// No description provided for @profileRecentPosts.
  ///
  /// In en, this message translates to:
  /// **'Recent Posts'**
  String get profileRecentPosts;

  /// No description provided for @profileNoRecentPosts.
  ///
  /// In en, this message translates to:
  /// **'No posts yet'**
  String get profileNoRecentPosts;

  /// No description provided for @profileSoldItems.
  ///
  /// In en, this message translates to:
  /// **'Sold Items'**
  String get profileSoldItems;

  /// No description provided for @profileNoSoldItems.
  ///
  /// In en, this message translates to:
  /// **'No sold items yet'**
  String get profileNoSoldItems;

  /// No description provided for @profileDirectRequest.
  ///
  /// In en, this message translates to:
  /// **'Request Service'**
  String get profileDirectRequest;

  /// No description provided for @profileDirectRequestTitle.
  ///
  /// In en, this message translates to:
  /// **'Send Task Request'**
  String get profileDirectRequestTitle;

  /// No description provided for @profileDirectRequestSuccess.
  ///
  /// In en, this message translates to:
  /// **'Task request sent successfully'**
  String get profileDirectRequestSuccess;

  /// No description provided for @profileDirectRequestHintTitle.
  ///
  /// In en, this message translates to:
  /// **'Task title'**
  String get profileDirectRequestHintTitle;

  /// No description provided for @profileDirectRequestHintDescription.
  ///
  /// In en, this message translates to:
  /// **'Task description (optional)'**
  String get profileDirectRequestHintDescription;

  /// No description provided for @profileDirectRequestHintPrice.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get profileDirectRequestHintPrice;

  /// No description provided for @profileDirectRequestHintTaskType.
  ///
  /// In en, this message translates to:
  /// **'Task type'**
  String get profileDirectRequestHintTaskType;

  /// No description provided for @profileDirectRequestSubmit.
  ///
  /// In en, this message translates to:
  /// **'Send Request'**
  String get profileDirectRequestSubmit;

  /// No description provided for @profileMySoldItems.
  ///
  /// In en, this message translates to:
  /// **'My Sold Items'**
  String get profileMySoldItems;

  /// No description provided for @profileMySoldItemsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View your sold flea market items'**
  String get profileMySoldItemsSubtitle;

  /// No description provided for @commonDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get commonDefault;

  /// No description provided for @paymentIncorrectCvc.
  ///
  /// In en, this message translates to:
  /// **'Incorrect CVC'**
  String get paymentIncorrectCvc;

  /// No description provided for @paymentIncorrectCardNumber.
  ///
  /// In en, this message translates to:
  /// **'Incorrect card number'**
  String get paymentIncorrectCardNumber;

  /// No description provided for @paymentAuthenticationRequired.
  ///
  /// In en, this message translates to:
  /// **'Authentication required'**
  String get paymentAuthenticationRequired;

  /// No description provided for @paymentProcessingError.
  ///
  /// In en, this message translates to:
  /// **'Payment processing error'**
  String get paymentProcessingError;

  /// No description provided for @paymentTooManyRequests.
  ///
  /// In en, this message translates to:
  /// **'Too many requests, please try later'**
  String get paymentTooManyRequests;

  /// No description provided for @paymentInvalidRequest.
  ///
  /// In en, this message translates to:
  /// **'Invalid payment request'**
  String get paymentInvalidRequest;

  /// No description provided for @transactionTypePayment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get transactionTypePayment;

  /// No description provided for @transactionTypePayout.
  ///
  /// In en, this message translates to:
  /// **'Payout'**
  String get transactionTypePayout;

  /// No description provided for @transactionTypeRefund.
  ///
  /// In en, this message translates to:
  /// **'Refund'**
  String get transactionTypeRefund;

  /// No description provided for @transactionTypeFee.
  ///
  /// In en, this message translates to:
  /// **'Service Fee'**
  String get transactionTypeFee;

  /// No description provided for @supportChatTitle.
  ///
  /// In en, this message translates to:
  /// **'Linker'**
  String get supportChatTitle;

  /// No description provided for @supportChatConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get supportChatConnecting;

  /// No description provided for @supportChatHumanOnline.
  ///
  /// In en, this message translates to:
  /// **'Human agent is online'**
  String get supportChatHumanOnline;

  /// No description provided for @supportChatConnectButton.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get supportChatConnectButton;

  /// No description provided for @supportChatHumanOffline.
  ///
  /// In en, this message translates to:
  /// **'No agents online. Email support@link2ur.com'**
  String get supportChatHumanOffline;

  /// No description provided for @supportChatConnected.
  ///
  /// In en, this message translates to:
  /// **'Human Support'**
  String get supportChatConnected;

  /// No description provided for @supportChatEnded.
  ///
  /// In en, this message translates to:
  /// **'Conversation ended'**
  String get supportChatEnded;

  /// No description provided for @supportChatReturnToAI.
  ///
  /// In en, this message translates to:
  /// **'Back to AI'**
  String get supportChatReturnToAI;

  /// No description provided for @supportChatDivider.
  ///
  /// In en, this message translates to:
  /// **'Connected to human support'**
  String get supportChatDivider;

  /// No description provided for @supportChatHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get supportChatHistory;

  /// No description provided for @aiChatTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Assistant'**
  String get aiChatTitle;

  /// No description provided for @aiChatNewConversation.
  ///
  /// In en, this message translates to:
  /// **'New conversation'**
  String get aiChatNewConversation;

  /// No description provided for @aiChatReplying.
  ///
  /// In en, this message translates to:
  /// **'AI is replying...'**
  String get aiChatReplying;

  /// No description provided for @aiChatInputHint.
  ///
  /// In en, this message translates to:
  /// **'Type a message...'**
  String get aiChatInputHint;

  /// No description provided for @aiChatViewMyTasks.
  ///
  /// In en, this message translates to:
  /// **'View my tasks'**
  String get aiChatViewMyTasks;

  /// No description provided for @aiChatSearchTasks.
  ///
  /// In en, this message translates to:
  /// **'Search available tasks'**
  String get aiChatSearchTasks;

  /// No description provided for @aiChatWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Hi, I\'m Linker'**
  String get aiChatWelcomeTitle;

  /// No description provided for @aiChatWelcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'How can I help you?'**
  String get aiChatWelcomeSubtitle;

  /// No description provided for @aiChatWelcomeIntro.
  ///
  /// In en, this message translates to:
  /// **'I\'m Link2Ur\'s AI assistant. I can help you check task status, search tasks, answer platform rules, view points and coupons, and more. Type your question below or tap a quick question to get started.'**
  String get aiChatWelcomeIntro;

  /// No description provided for @aiChatQuickStart.
  ///
  /// In en, this message translates to:
  /// **'Quick start'**
  String get aiChatQuickStart;

  /// No description provided for @aiChatStartNewConversation.
  ///
  /// In en, this message translates to:
  /// **'Start new conversation'**
  String get aiChatStartNewConversation;

  /// No description provided for @aiChatNoConversations.
  ///
  /// In en, this message translates to:
  /// **'No conversations yet'**
  String get aiChatNoConversations;

  /// No description provided for @locationFetchFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to get location: {error}'**
  String locationFetchFailed(String error);

  /// No description provided for @toolCallQueryMyTasks.
  ///
  /// In en, this message translates to:
  /// **'Query my tasks'**
  String get toolCallQueryMyTasks;

  /// No description provided for @toolCallGetTaskDetail.
  ///
  /// In en, this message translates to:
  /// **'Get task details'**
  String get toolCallGetTaskDetail;

  /// No description provided for @toolCallSearchTasks.
  ///
  /// In en, this message translates to:
  /// **'Search tasks'**
  String get toolCallSearchTasks;

  /// No description provided for @toolCallGetMyProfile.
  ///
  /// In en, this message translates to:
  /// **'Get my profile'**
  String get toolCallGetMyProfile;

  /// No description provided for @toolCallGetPlatformFaq.
  ///
  /// In en, this message translates to:
  /// **'Query FAQ'**
  String get toolCallGetPlatformFaq;

  /// No description provided for @toolCallCheckCsAvailability.
  ///
  /// In en, this message translates to:
  /// **'Check support online'**
  String get toolCallCheckCsAvailability;

  /// No description provided for @toolCallGetMyPointsAndCoupons.
  ///
  /// In en, this message translates to:
  /// **'Points & coupons'**
  String get toolCallGetMyPointsAndCoupons;

  /// No description provided for @toolCallListActivities.
  ///
  /// In en, this message translates to:
  /// **'Browse activities'**
  String get toolCallListActivities;

  /// No description provided for @toolCallGetMyNotificationsSummary.
  ///
  /// In en, this message translates to:
  /// **'View notifications'**
  String get toolCallGetMyNotificationsSummary;

  /// No description provided for @toolCallListMyForumPosts.
  ///
  /// In en, this message translates to:
  /// **'My forum posts'**
  String get toolCallListMyForumPosts;

  /// No description provided for @toolCallSearchFleaMarket.
  ///
  /// In en, this message translates to:
  /// **'Search flea market'**
  String get toolCallSearchFleaMarket;

  /// No description provided for @toolCallGetLeaderboardSummary.
  ///
  /// In en, this message translates to:
  /// **'View leaderboard'**
  String get toolCallGetLeaderboardSummary;

  /// No description provided for @toolCallListTaskExperts.
  ///
  /// In en, this message translates to:
  /// **'Browse experts'**
  String get toolCallListTaskExperts;

  /// No description provided for @toolCallLoadingQueryMyTasks.
  ///
  /// In en, this message translates to:
  /// **'Checking your tasks…'**
  String get toolCallLoadingQueryMyTasks;

  /// No description provided for @toolCallLoadingGetTaskDetail.
  ///
  /// In en, this message translates to:
  /// **'Fetching task details…'**
  String get toolCallLoadingGetTaskDetail;

  /// No description provided for @toolCallLoadingSearchTasks.
  ///
  /// In en, this message translates to:
  /// **'Searching tasks…'**
  String get toolCallLoadingSearchTasks;

  /// No description provided for @toolCallLoadingGetMyProfile.
  ///
  /// In en, this message translates to:
  /// **'Loading your profile…'**
  String get toolCallLoadingGetMyProfile;

  /// No description provided for @toolCallLoadingGetPlatformFaq.
  ///
  /// In en, this message translates to:
  /// **'Looking up FAQ…'**
  String get toolCallLoadingGetPlatformFaq;

  /// No description provided for @toolCallLoadingCheckCsAvailability.
  ///
  /// In en, this message translates to:
  /// **'Checking if support is online…'**
  String get toolCallLoadingCheckCsAvailability;

  /// No description provided for @toolCallLoadingGetMyPointsAndCoupons.
  ///
  /// In en, this message translates to:
  /// **'Loading points & coupons…'**
  String get toolCallLoadingGetMyPointsAndCoupons;

  /// No description provided for @toolCallLoadingListActivities.
  ///
  /// In en, this message translates to:
  /// **'Loading activities…'**
  String get toolCallLoadingListActivities;

  /// No description provided for @toolCallLoadingGetMyNotificationsSummary.
  ///
  /// In en, this message translates to:
  /// **'Loading notifications…'**
  String get toolCallLoadingGetMyNotificationsSummary;

  /// No description provided for @toolCallLoadingListMyForumPosts.
  ///
  /// In en, this message translates to:
  /// **'Loading your posts…'**
  String get toolCallLoadingListMyForumPosts;

  /// No description provided for @toolCallLoadingSearchFleaMarket.
  ///
  /// In en, this message translates to:
  /// **'Searching flea market…'**
  String get toolCallLoadingSearchFleaMarket;

  /// No description provided for @toolCallLoadingGetLeaderboardSummary.
  ///
  /// In en, this message translates to:
  /// **'Loading leaderboard…'**
  String get toolCallLoadingGetLeaderboardSummary;

  /// No description provided for @toolCallLoadingListTaskExperts.
  ///
  /// In en, this message translates to:
  /// **'Loading experts…'**
  String get toolCallLoadingListTaskExperts;

  /// No description provided for @toolCallGetMyWalletSummary.
  ///
  /// In en, this message translates to:
  /// **'Wallet summary'**
  String get toolCallGetMyWalletSummary;

  /// No description provided for @toolCallGetMyMessagesSummary.
  ///
  /// In en, this message translates to:
  /// **'Chat summary'**
  String get toolCallGetMyMessagesSummary;

  /// No description provided for @toolCallGetMyVipStatus.
  ///
  /// In en, this message translates to:
  /// **'VIP status'**
  String get toolCallGetMyVipStatus;

  /// No description provided for @toolCallGetMyStudentVerification.
  ///
  /// In en, this message translates to:
  /// **'Student verification'**
  String get toolCallGetMyStudentVerification;

  /// No description provided for @toolCallGetMyCheckinStatus.
  ///
  /// In en, this message translates to:
  /// **'Check-in status'**
  String get toolCallGetMyCheckinStatus;

  /// No description provided for @toolCallGetMyFleaMarketItems.
  ///
  /// In en, this message translates to:
  /// **'My flea market'**
  String get toolCallGetMyFleaMarketItems;

  /// No description provided for @toolCallSearchForumPosts.
  ///
  /// In en, this message translates to:
  /// **'Search forum'**
  String get toolCallSearchForumPosts;

  /// No description provided for @toolCallLoadingGetMyWalletSummary.
  ///
  /// In en, this message translates to:
  /// **'Loading wallet info…'**
  String get toolCallLoadingGetMyWalletSummary;

  /// No description provided for @toolCallLoadingGetMyMessagesSummary.
  ///
  /// In en, this message translates to:
  /// **'Loading chat summary…'**
  String get toolCallLoadingGetMyMessagesSummary;

  /// No description provided for @toolCallLoadingGetMyVipStatus.
  ///
  /// In en, this message translates to:
  /// **'Checking VIP status…'**
  String get toolCallLoadingGetMyVipStatus;

  /// No description provided for @toolCallLoadingGetMyStudentVerification.
  ///
  /// In en, this message translates to:
  /// **'Checking verification…'**
  String get toolCallLoadingGetMyStudentVerification;

  /// No description provided for @toolCallLoadingGetMyCheckinStatus.
  ///
  /// In en, this message translates to:
  /// **'Checking check-in…'**
  String get toolCallLoadingGetMyCheckinStatus;

  /// No description provided for @toolCallLoadingGetMyFleaMarketItems.
  ///
  /// In en, this message translates to:
  /// **'Loading your items…'**
  String get toolCallLoadingGetMyFleaMarketItems;

  /// No description provided for @toolCallLoadingSearchForumPosts.
  ///
  /// In en, this message translates to:
  /// **'Searching forum…'**
  String get toolCallLoadingSearchForumPosts;

  /// No description provided for @toolCallPrepareTaskDraft.
  ///
  /// In en, this message translates to:
  /// **'Task draft'**
  String get toolCallPrepareTaskDraft;

  /// No description provided for @toolCallLoadingPrepareTaskDraft.
  ///
  /// In en, this message translates to:
  /// **'Preparing task draft…'**
  String get toolCallLoadingPrepareTaskDraft;

  /// No description provided for @aiTaskDraftTitle.
  ///
  /// In en, this message translates to:
  /// **'Task Draft'**
  String get aiTaskDraftTitle;

  /// No description provided for @aiTaskDraftConfirmButton.
  ///
  /// In en, this message translates to:
  /// **'Review & Publish'**
  String get aiTaskDraftConfirmButton;

  /// No description provided for @expertApplicationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Service Applications'**
  String get expertApplicationsTitle;

  /// No description provided for @expertApplicationsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No Applications'**
  String get expertApplicationsEmpty;

  /// No description provided for @expertApplicationsEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t received any service applications yet.'**
  String get expertApplicationsEmptyMessage;

  /// No description provided for @expertApplicationApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get expertApplicationApprove;

  /// No description provided for @expertApplicationReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get expertApplicationReject;

  /// No description provided for @expertApplicationCounterOffer.
  ///
  /// In en, this message translates to:
  /// **'Counter Offer'**
  String get expertApplicationCounterOffer;

  /// No description provided for @expertApplicationApproved.
  ///
  /// In en, this message translates to:
  /// **'Application approved successfully'**
  String get expertApplicationApproved;

  /// No description provided for @expertApplicationRejected.
  ///
  /// In en, this message translates to:
  /// **'Application rejected'**
  String get expertApplicationRejected;

  /// No description provided for @expertApplicationCounterOfferSent.
  ///
  /// In en, this message translates to:
  /// **'Counter offer sent'**
  String get expertApplicationCounterOfferSent;

  /// No description provided for @expertApplicationActionFailed.
  ///
  /// In en, this message translates to:
  /// **'Operation failed, please try again'**
  String get expertApplicationActionFailed;

  /// No description provided for @expertApplicationRejectReason.
  ///
  /// In en, this message translates to:
  /// **'Reject Reason (Optional)'**
  String get expertApplicationRejectReason;

  /// No description provided for @expertApplicationRejectReasonHint.
  ///
  /// In en, this message translates to:
  /// **'Please enter the reason for rejection…'**
  String get expertApplicationRejectReasonHint;

  /// No description provided for @expertApplicationCounterPrice.
  ///
  /// In en, this message translates to:
  /// **'Your Price'**
  String get expertApplicationCounterPrice;

  /// No description provided for @expertApplicationCounterPriceHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your counter offer price'**
  String get expertApplicationCounterPriceHint;

  /// No description provided for @expertApplicationCounterMessage.
  ///
  /// In en, this message translates to:
  /// **'Message (Optional)'**
  String get expertApplicationCounterMessage;

  /// No description provided for @expertApplicationCounterMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Add a note about your counter offer…'**
  String get expertApplicationCounterMessageHint;

  /// No description provided for @expertApplicationConfirmApprove.
  ///
  /// In en, this message translates to:
  /// **'Confirm Approve'**
  String get expertApplicationConfirmApprove;

  /// No description provided for @expertApplicationConfirmApproveMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to approve this application? A task and payment will be created.'**
  String get expertApplicationConfirmApproveMessage;

  /// No description provided for @expertApplicationConfirmReject.
  ///
  /// In en, this message translates to:
  /// **'Confirm Reject'**
  String get expertApplicationConfirmReject;

  /// No description provided for @expertApplicationConfirmRejectMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to reject this application?'**
  String get expertApplicationConfirmRejectMessage;

  /// No description provided for @expertApplicationStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get expertApplicationStatusPending;

  /// No description provided for @expertApplicationStatusNegotiating.
  ///
  /// In en, this message translates to:
  /// **'Negotiating'**
  String get expertApplicationStatusNegotiating;

  /// No description provided for @expertApplicationStatusPriceAgreed.
  ///
  /// In en, this message translates to:
  /// **'Price Agreed'**
  String get expertApplicationStatusPriceAgreed;

  /// No description provided for @expertApplicationStatusApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get expertApplicationStatusApproved;

  /// No description provided for @expertApplicationStatusRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get expertApplicationStatusRejected;

  /// No description provided for @expertApplicationStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get expertApplicationStatusCancelled;

  /// No description provided for @expertApplicationApplicant.
  ///
  /// In en, this message translates to:
  /// **'Applicant'**
  String get expertApplicationApplicant;

  /// No description provided for @expertApplicationService.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get expertApplicationService;

  /// No description provided for @expertApplicationMessage.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get expertApplicationMessage;

  /// No description provided for @expertApplicationPrice.
  ///
  /// In en, this message translates to:
  /// **'Offered Price'**
  String get expertApplicationPrice;

  /// No description provided for @expertApplicationBasePrice.
  ///
  /// In en, this message translates to:
  /// **'Base Price'**
  String get expertApplicationBasePrice;

  /// No description provided for @commonUnnamed.
  ///
  /// In en, this message translates to:
  /// **'Unnamed'**
  String get commonUnnamed;

  /// No description provided for @commonImageUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Image upload failed: {error}'**
  String commonImageUploadFailed(String error);

  /// No description provided for @commonImageCount.
  ///
  /// In en, this message translates to:
  /// **'{current}/{max}'**
  String commonImageCount(int current, int max);

  /// No description provided for @paymentCardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Visa, Mastercard, AMEX'**
  String get paymentCardSubtitle;

  /// No description provided for @paymentWeChatPaySubtitle.
  ///
  /// In en, this message translates to:
  /// **'WeChat Pay (Stripe)'**
  String get paymentWeChatPaySubtitle;

  /// No description provided for @paymentAlipaySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Alipay (Stripe)'**
  String get paymentAlipaySubtitle;

  /// No description provided for @commonCurrencySymbol.
  ///
  /// In en, this message translates to:
  /// **'£ '**
  String get commonCurrencySymbol;

  /// No description provided for @forumDeletePostConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this post? This action cannot be undone.'**
  String get forumDeletePostConfirm;

  /// No description provided for @forumPostDeleted.
  ///
  /// In en, this message translates to:
  /// **'Post deleted'**
  String get forumPostDeleted;

  /// No description provided for @forumPostUpdated.
  ///
  /// In en, this message translates to:
  /// **'Post updated'**
  String get forumPostUpdated;

  /// No description provided for @forumReplyDeleted.
  ///
  /// In en, this message translates to:
  /// **'Reply deleted'**
  String get forumReplyDeleted;

  /// No description provided for @forumDeleteReplyConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this reply?'**
  String get forumDeleteReplyConfirm;

  /// No description provided for @fleaMarketDeleteItemConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this listing? This action cannot be undone.'**
  String get fleaMarketDeleteItemConfirm;

  /// No description provided for @fleaMarketItemDeleted.
  ///
  /// In en, this message translates to:
  /// **'Listing deleted'**
  String get fleaMarketItemDeleted;

  /// No description provided for @taskEvidenceTitle.
  ///
  /// In en, this message translates to:
  /// **'Completion Evidence'**
  String get taskEvidenceTitle;

  /// No description provided for @taskEvidenceHint.
  ///
  /// In en, this message translates to:
  /// **'You have completed this task. You may upload evidence images or add a text description (optional) for the poster to confirm.'**
  String get taskEvidenceHint;

  /// No description provided for @taskEvidenceTextLabel.
  ///
  /// In en, this message translates to:
  /// **'Text description (optional)'**
  String get taskEvidenceTextLabel;

  /// No description provided for @taskEvidenceTextHint.
  ///
  /// In en, this message translates to:
  /// **'Describe what was done...'**
  String get taskEvidenceTextHint;

  /// No description provided for @taskEvidenceImagesLabel.
  ///
  /// In en, this message translates to:
  /// **'Evidence images (optional)'**
  String get taskEvidenceImagesLabel;

  /// No description provided for @taskEvidenceImageLimit.
  ///
  /// In en, this message translates to:
  /// **'Max 5MB per image, up to 5 images'**
  String get taskEvidenceImageLimit;

  /// No description provided for @taskEvidenceSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit completion'**
  String get taskEvidenceSubmit;

  /// No description provided for @taskEvidenceUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading images...'**
  String get taskEvidenceUploading;

  /// No description provided for @stripeSetupRequired.
  ///
  /// In en, this message translates to:
  /// **'Please set up your payout account before applying for tasks.'**
  String get stripeSetupRequired;

  /// No description provided for @stripeSetupAction.
  ///
  /// In en, this message translates to:
  /// **'Set up now'**
  String get stripeSetupAction;

  /// No description provided for @profileSendCode.
  ///
  /// In en, this message translates to:
  /// **'Send Code'**
  String get profileSendCode;

  /// No description provided for @profileResendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend'**
  String get profileResendCode;

  /// No description provided for @profileCodeSentSuccess.
  ///
  /// In en, this message translates to:
  /// **'Verification code sent'**
  String get profileCodeSentSuccess;

  /// No description provided for @profileEmailCodeSent.
  ///
  /// In en, this message translates to:
  /// **'Code sent to new email'**
  String get profileEmailCodeSent;

  /// No description provided for @profilePhoneCodeSent.
  ///
  /// In en, this message translates to:
  /// **'Code sent to new phone'**
  String get profilePhoneCodeSent;

  /// No description provided for @profileCountdownSeconds.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s'**
  String profileCountdownSeconds(int seconds);

  /// No description provided for @profileEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Email is required to send verification code'**
  String get profileEmailRequired;

  /// No description provided for @profilePhoneRequired.
  ///
  /// In en, this message translates to:
  /// **'Phone number is required to send verification code'**
  String get profilePhoneRequired;

  /// No description provided for @profileEmailUnchanged.
  ///
  /// In en, this message translates to:
  /// **'Please enter a different email address'**
  String get profileEmailUnchanged;

  /// No description provided for @profilePhoneUnchanged.
  ///
  /// In en, this message translates to:
  /// **'Please enter a different phone number'**
  String get profilePhoneUnchanged;

  /// No description provided for @profileEmailCodeRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter the email verification code'**
  String get profileEmailCodeRequired;

  /// No description provided for @profilePhoneCodeRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter the phone verification code'**
  String get profilePhoneCodeRequired;

  /// No description provided for @profileNormalizePhoneHint.
  ///
  /// In en, this message translates to:
  /// **'UK format: 07XXX or +44XXX'**
  String get profileNormalizePhoneHint;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.scriptCode) {
          case 'Hant':
            return AppLocalizationsZhHant();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
