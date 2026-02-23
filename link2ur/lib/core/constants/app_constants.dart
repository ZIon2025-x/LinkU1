/// 应用常量
class AppConstants {
  AppConstants._();

  /// 应用名称
  static const String appName = 'Link²Ur';
  static const String appNameAscii = 'Link2Ur';

  /// 应用ID
  static const String appId = 'com.link2ur.app';

  /// 任务类型
  static const List<String> taskTypes = [
    'delivery',      // 代取代送
    'shopping',      // 代购
    'tutoring',      // 辅导
    'translation',   // 翻译
    'design',        // 设计
    'programming',   // 编程
    'writing',       // 写作
    'photography',   // 摄影
    'moving',        // 搬家
    'cleaning',      // 清洁
    'repair',        // 维修
    'other',         // 其他
  ];

  /// 任务状态
  static const String taskStatusOpen = 'open';
  static const String taskStatusTaken = 'taken';
  static const String taskStatusInProgress = 'in_progress';
  static const String taskStatusPendingConfirmation = 'pending_confirmation';
  static const String taskStatusPendingPayment = 'pending_payment';
  static const String taskStatusCompleted = 'completed';
  static const String taskStatusCancelled = 'cancelled';
  static const String taskStatusDisputed = 'disputed';

  /// 任务来源
  static const String taskSourceNormal = 'normal';
  static const String taskSourceFleaMarket = 'flea_market';
  static const String taskSourceExpertService = 'expert_service';
  static const String taskSourceExpertActivity = 'expert_activity';

  /// 跳蚤市场商品状态
  static const String fleaMarketStatusActive = 'active';
  static const String fleaMarketStatusSold = 'sold';

  /// 退款状态
  static const String refundStatusPending = 'pending';
  static const String refundStatusCompleted = 'completed';

  /// 优惠券状态
  static const String couponStatusUnused = 'unused';
  static const String couponStatusUsed = 'used';
  static const String couponStatusExpired = 'expired';

  /// 学生认证状态
  static const String verificationStatusPending = 'pending';
  static const String verificationStatusExpired = 'expired';
  static const String verificationStatusRevoked = 'revoked';

  /// 跳蚤市场分类
  static const List<String> fleaMarketCategories = [
    'electronics',   // 电子产品
    'books',         // 书籍教材
    'clothing',      // 服饰鞋包
    'furniture',     // 家具家电
    'sports',        // 运动户外
    'beauty',        // 美妆护肤
    'food',          // 食品饮料
    'tickets',       // 票券卡券
    'other',         // 其他
  ];

  /// 货币
  static const String currencyUSD = 'USD';
  static const String currencyCNY = 'CNY';
  static const String currencyGBP = 'GBP';
  static const String currencyEUR = 'EUR';

  /// 分页
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  /// 图片
  static const int maxImageCount = 9;
  static const int maxImageSizeMB = 10;
  static const List<String> allowedImageTypes = ['jpg', 'jpeg', 'png', 'gif', 'webp'];

  /// 文本限制
  static const int maxTitleLength = 100;
  static const int maxDescriptionLength = 2000;
  static const int maxCommentLength = 500;
  static const int maxBioLength = 200;

  /// 缓存key前缀
  static const String cacheKeyPrefix = 'link2ur_cache_';

  /// 动画时长
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration animationDurationFast = Duration(milliseconds: 150);
  static const Duration animationDurationSlow = Duration(milliseconds: 500);
}
