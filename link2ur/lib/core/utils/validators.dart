/// 表单验证工具
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
  /// 英国手机号以 07 开头，共 11 位；或去掉前导 0 以 7 开头，共 10 位
  static final RegExp _phoneRegexUK = RegExp(r'^0?7\d{9}$');

  /// 密码正则（至少8位，包含字母和数字）
  static final RegExp _passwordRegex = RegExp(r'^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d@$!%*#?&]{8,}$');

  /// URL正则
  static final RegExp _urlRegex = RegExp(
    r'^https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)$',
  );

  // ==================== 验证方法 ====================
  /// 验证邮箱
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return '请输入邮箱地址';
    }
    if (!_emailRegex.hasMatch(value)) {
      return '请输入有效的邮箱地址';
    }
    return null;
  }

  /// 验证手机号
  static String? validatePhone(String? value, {bool international = false}) {
    if (value == null || value.isEmpty) {
      return '请输入手机号';
    }
    final regex = international ? _phoneRegexIntl : _phoneRegexCN;
    if (!regex.hasMatch(value)) {
      return '请输入有效的手机号';
    }
    return null;
  }

  /// 验证英国手机号（用户只输入本地号码，不含 +44）
  static String? validateUKPhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your phone number';
    }
    if (!_phoneRegexUK.hasMatch(value)) {
      return 'Please enter a valid UK mobile number';
    }
    return null;
  }

  /// 验证密码
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return '请输入密码';
    }
    if (value.length < 8) {
      return '密码长度至少8位';
    }
    if (!_passwordRegex.hasMatch(value)) {
      return '密码需包含字母和数字';
    }
    return null;
  }

  /// 验证确认密码
  static String? validateConfirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return '请确认密码';
    }
    if (value != password) {
      return '两次输入的密码不一致';
    }
    return null;
  }

  /// 验证验证码
  static String? validateVerificationCode(String? value, {int length = 6}) {
    if (value == null || value.isEmpty) {
      return '请输入验证码';
    }
    if (value.length != length) {
      return '验证码应为$length位';
    }
    if (!RegExp(r'^\d+$').hasMatch(value)) {
      return '验证码只能包含数字';
    }
    return null;
  }

  /// 验证用户名
  static String? validateUsername(String? value) {
    if (value == null || value.isEmpty) {
      return '请输入用户名';
    }
    if (value.length < 2) {
      return '用户名至少2个字符';
    }
    if (value.length > 20) {
      return '用户名最多20个字符';
    }
    return null;
  }

  /// 验证标题
  static String? validateTitle(String? value, {int maxLength = 100}) {
    if (value == null || value.isEmpty) {
      return '请输入标题';
    }
    if (value.length > maxLength) {
      return '标题最多$maxLength个字符';
    }
    return null;
  }

  /// 验证描述
  static String? validateDescription(String? value, {int maxLength = 2000, bool required = true}) {
    if (required && (value == null || value.isEmpty)) {
      return '请输入描述';
    }
    if (value != null && value.length > maxLength) {
      return '描述最多$maxLength个字符';
    }
    return null;
  }

  /// 验证金额
  static String? validateAmount(String? value, {double? min, double? max}) {
    if (value == null || value.isEmpty) {
      return '请输入金额';
    }
    final amount = double.tryParse(value);
    if (amount == null) {
      return '请输入有效的金额';
    }
    if (amount <= 0) {
      return '金额必须大于0';
    }
    if (min != null && amount < min) {
      return '金额不能小于$min';
    }
    if (max != null && amount > max) {
      return '金额不能大于$max';
    }
    return null;
  }

  /// 验证URL
  static String? validateUrl(String? value, {bool required = false}) {
    if (value == null || value.isEmpty) {
      return required ? '请输入URL' : null;
    }
    if (!_urlRegex.hasMatch(value)) {
      return '请输入有效的URL';
    }
    return null;
  }

  /// 验证非空
  static String? validateRequired(String? value, {String fieldName = '此项'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName不能为空';
    }
    return null;
  }

  /// 验证长度范围
  static String? validateLength(
    String? value, {
    required String fieldName,
    int? min,
    int? max,
  }) {
    if (value == null || value.isEmpty) {
      return null;
    }
    if (min != null && value.length < min) {
      return '$fieldName至少$min个字符';
    }
    if (max != null && value.length > max) {
      return '$fieldName最多$max个字符';
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
  static bool isValidPassword(String password) => _passwordRegex.hasMatch(password);

  /// 是否有效URL
  static bool isValidUrl(String url) => _urlRegex.hasMatch(url);
}
