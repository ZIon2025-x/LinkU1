import '../../l10n/app_localizations.dart';

/// 表单验证工具
/// 所有方法接受可选的 [l10n] 参数，传入时返回本地化文本，否则返回英文默认值。
class Validators {
  Validators._();

  /// 邮箱正则
  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  /// 手机号正则（中国大陆）
  static final RegExp _phoneRegexCN = RegExp(r'^1[3-9]\d{9}$');

  /// 手机号正则（国际）
  static final RegExp _phoneRegexIntl = RegExp(r'^\+?[1-9]\d{6,14}$');

  /// 手机号正则（英国 UK）— 用户只输入本地号码（不含 +44）
  static final RegExp _phoneRegexUK = RegExp(r'^0?7\d{9}$');

  /// 密码正则（至少8位，包含字母和数字）
  static final RegExp _passwordRegex =
      RegExp(r'^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d@$!%*#?&]{8,}$');

  /// URL正则
  static final RegExp _urlRegex = RegExp(
    r'^https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)$',
  );

  // ==================== 验证方法 ====================
  /// 验证邮箱
  static String? validateEmail(String? value, {AppLocalizations? l10n}) {
    if (value == null || value.isEmpty) {
      return l10n?.validatorEmailRequired ?? 'Please enter email address';
    }
    if (!_emailRegex.hasMatch(value)) {
      return l10n?.validatorEmailInvalid ?? 'Please enter a valid email address';
    }
    return null;
  }

  /// 验证手机号
  static String? validatePhone(String? value,
      {bool international = false, AppLocalizations? l10n}) {
    if (value == null || value.isEmpty) {
      return l10n?.validatorPhoneRequired ?? 'Please enter phone number';
    }
    final regex = international ? _phoneRegexIntl : _phoneRegexCN;
    if (!regex.hasMatch(value)) {
      return l10n?.validatorPhoneInvalid ?? 'Please enter a valid phone number';
    }
    return null;
  }

  /// 验证英国手机号（用户只输入本地号码，不含 +44）
  static String? validateUKPhone(String? value, {AppLocalizations? l10n}) {
    if (value == null || value.isEmpty) {
      return l10n?.validatorUKPhoneRequired ?? 'Please enter your phone number';
    }
    if (!_phoneRegexUK.hasMatch(value)) {
      return l10n?.validatorUKPhoneInvalid ??
          'Please enter a valid UK mobile number';
    }
    return null;
  }

  /// 验证密码
  static String? validatePassword(String? value, {AppLocalizations? l10n}) {
    if (value == null || value.isEmpty) {
      return l10n?.validatorPasswordRequired ?? 'Please enter password';
    }
    if (value.length < 8) {
      return l10n?.validatorPasswordMinLength ??
          'Password must be at least 8 characters';
    }
    if (!_passwordRegex.hasMatch(value)) {
      return l10n?.validatorPasswordFormat ??
          'Password must contain both letters and numbers';
    }
    return null;
  }

  /// 验证确认密码
  static String? validateConfirmPassword(String? value, String password,
      {AppLocalizations? l10n}) {
    if (value == null || value.isEmpty) {
      return l10n?.validatorConfirmPasswordRequired ??
          'Please confirm password';
    }
    if (value != password) {
      return l10n?.validatorPasswordMismatch ?? 'Passwords do not match';
    }
    return null;
  }

  /// 验证验证码
  static String? validateVerificationCode(String? value,
      {int length = 6, AppLocalizations? l10n}) {
    if (value == null || value.isEmpty) {
      return l10n?.validatorCodeRequired ?? 'Please enter verification code';
    }
    if (value.length != length) {
      return l10n?.validatorCodeLength(length) ??
          'Verification code must be $length digits';
    }
    if (!RegExp(r'^\d+$').hasMatch(value)) {
      return l10n?.validatorCodeDigitsOnly ??
          'Verification code must contain only digits';
    }
    return null;
  }

  /// 验证用户名
  static String? validateUsername(String? value, {AppLocalizations? l10n}) {
    if (value == null || value.isEmpty) {
      return l10n?.validatorUsernameRequired ?? 'Please enter username';
    }
    if (value.length < 2) {
      return l10n?.validatorUsernameMinLength ??
          'Username must be at least 2 characters';
    }
    if (value.length > 20) {
      return l10n?.validatorUsernameMaxLength ??
          'Username must be at most 20 characters';
    }
    return null;
  }

  /// 验证标题
  static String? validateTitle(String? value,
      {int maxLength = 100, AppLocalizations? l10n}) {
    if (value == null || value.isEmpty) {
      return l10n?.validatorTitleRequired ?? 'Please enter title';
    }
    if (value.length > maxLength) {
      return l10n?.validatorTitleMaxLength(maxLength) ??
          'Title must be at most $maxLength characters';
    }
    return null;
  }

  /// 验证描述
  static String? validateDescription(String? value,
      {int maxLength = 2000, bool required = true, AppLocalizations? l10n}) {
    if (required && (value == null || value.isEmpty)) {
      return l10n?.validatorDescriptionRequired ?? 'Please enter description';
    }
    if (value != null && value.length > maxLength) {
      return l10n?.validatorDescriptionMaxLength(maxLength) ??
          'Description must be at most $maxLength characters';
    }
    return null;
  }

  /// 验证金额
  static String? validateAmount(String? value,
      {double? min, double? max, AppLocalizations? l10n}) {
    if (value == null || value.isEmpty) {
      return l10n?.validatorAmountRequired ?? 'Please enter amount';
    }
    final amount = double.tryParse(value);
    if (amount == null) {
      return l10n?.validatorAmountInvalid ?? 'Please enter a valid amount';
    }
    if (amount <= 0) {
      return l10n?.validatorAmountPositive ?? 'Amount must be greater than 0';
    }
    if (min != null && amount < min) {
      return l10n?.validatorAmountMin(min) ?? 'Amount cannot be less than $min';
    }
    if (max != null && amount > max) {
      return l10n?.validatorAmountMax(max) ??
          'Amount cannot be greater than $max';
    }
    return null;
  }

  /// 验证URL
  static String? validateUrl(String? value,
      {bool required = false, AppLocalizations? l10n}) {
    if (value == null || value.isEmpty) {
      return required
          ? (l10n?.validatorUrlRequired ?? 'Please enter URL')
          : null;
    }
    if (!_urlRegex.hasMatch(value)) {
      return l10n?.validatorUrlInvalid ?? 'Please enter a valid URL';
    }
    return null;
  }

  /// 验证非空
  static String? validateRequired(String? value,
      {String fieldName = 'This field', AppLocalizations? l10n}) {
    if (value == null || value.trim().isEmpty) {
      return l10n?.validatorFieldRequired(fieldName) ??
          '$fieldName is required';
    }
    return null;
  }

  /// 验证长度范围
  static String? validateLength(
    String? value, {
    required String fieldName,
    int? min,
    int? max,
    AppLocalizations? l10n,
  }) {
    if (value == null || value.isEmpty) {
      return null;
    }
    if (min != null && value.length < min) {
      return l10n?.validatorFieldMinLength(fieldName, min) ??
          '$fieldName must be at least $min characters';
    }
    if (max != null && value.length > max) {
      return l10n?.validatorFieldMaxLength(fieldName, max) ??
          '$fieldName must be at most $max characters';
    }
    return null;
  }

  // ==================== 工具方法 ====================
  /// 是否有效邮箱
  static bool isValidEmail(String email) => _emailRegex.hasMatch(email);

  /// 是否有效手机号
  static bool isValidPhone(String phone, {bool international = false}) {
    final regex = international ? _phoneRegexIntl : _phoneRegexCN;
    return regex.hasMatch(phone);
  }

  /// 是否有效英国手机号
  static bool isValidUKPhone(String phone) => _phoneRegexUK.hasMatch(phone);

  /// 是否有效密码
  static bool isValidPassword(String password) =>
      _passwordRegex.hasMatch(password);

  /// 是否有效URL
  static bool isValidUrl(String url) => _urlRegex.hasMatch(url);
}
