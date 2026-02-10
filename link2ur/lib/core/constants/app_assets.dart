/// 应用资源路径常量
/// 与iOS Assets.xcassets对齐
class AppAssets {
  AppAssets._();

  // ==================== 图片 ====================
  /// Logo
  static const String logo = 'assets/images/logo.png';

  /// App图标
  static const String appIcon = 'assets/images/app_icon.png';

  /// 默认头像
  static const String defaultAvatar = 'assets/images/default_avatar.png';

  /// 跳蚤市场Banner
  static const String fleaMarketBanner = 'assets/images/flea_market_banner.jpeg';

  /// 学生认证Banner
  static const String studentVerificationBanner = 'assets/images/student_verification_banner.webp';

  /// 通用图片
  static const String any = 'assets/images/any.png';

  /// 服务图片
  static const String service = 'assets/images/service.webp';

  // ==================== 预设头像 ====================
  static const String avatar1 = 'assets/images/avatars/avatar1.png';
  static const String avatar2 = 'assets/images/avatars/avatar2.png';
  static const String avatar3 = 'assets/images/avatars/avatar3.png';
  static const String avatar4 = 'assets/images/avatars/avatar4.png';
  static const String avatar5 = 'assets/images/avatars/avatar5.png';

  static const List<String> presetAvatars = [
    avatar1,
    avatar2,
    avatar3,
    avatar4,
    avatar5,
  ];

  /// 后端预设头像路径 -> 本地 asset 映射
  /// 后端存储格式: /static/avatar1.png
  static const Map<String, String> avatarPathMap = {
    '/static/avatar1.png': avatar1,
    '/static/avatar2.png': avatar2,
    '/static/avatar3.png': avatar3,
    '/static/avatar4.png': avatar4,
    '/static/avatar5.png': avatar5,
  };

  /// 判断是否为预设头像路径（后端格式）
  static bool isPresetAvatar(String? path) {
    if (path == null || path.isEmpty) return false;
    return avatarPathMap.containsKey(path);
  }

  /// 获取预设头像对应的本地 asset 路径
  static String? getLocalAvatarAsset(String? path) {
    if (path == null || path.isEmpty) return null;
    return avatarPathMap[path];
  }

  /// 判断是否为官方/系统头像（显示 logo）
  static bool isOfficialAvatar(String? path) {
    if (path == null || path.isEmpty) return false;
    return path == '/static/logo.png' ||
        path == 'official' ||
        path == 'system';
  }

  // ==================== 社交媒体图标 ====================
  static const String wechat = 'assets/images/social/wechat.png';
  static const String wechatPay = 'assets/images/social/wechat_pay.png';
  static const String wechatMoments = 'assets/images/social/wechat_moments.png';
  static const String alipay = 'assets/images/social/alipay.png';
  static const String qq = 'assets/images/social/qq.png';
  static const String qzone = 'assets/images/social/qzone.png';
  static const String weibo = 'assets/images/social/weibo.png';
  static const String facebook = 'assets/images/social/facebook.png';
  static const String instagram = 'assets/images/social/instagram.png';
  static const String xTwitter = 'assets/images/social/x_twitter.png';
}
