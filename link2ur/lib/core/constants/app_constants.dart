import '../utils/helpers.dart';

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
    'pickup_dropoff', // 接送
    'cooking',       // 做饭/餐饮
    'language_help', // 语言协助
    'government',    // 官方事务
    'pet_care',      // 宠物照料
    'errand',        // 跑腿
    'accompany',     // 陪同
    'digital',       // 数码/IT
    'rental_housing', // 租房协助
    'campus_life',   // 校园生活
    'second_hand',   // 二手交易
    'other',         // 其他
  ];

  /// 任务状态（与后端 Task.status 对齐）
  static const String taskStatusOpen = 'open';
  static const String taskStatusTaken = 'taken';
  static const String taskStatusInProgress = 'in_progress';
  static const String taskStatusPendingConfirmation = 'pending_confirmation';
  static const String taskStatusPendingPayment = 'pending_payment';
  static const String taskStatusCompleted = 'completed';
  static const String taskStatusCancelled = 'cancelled';
  static const String taskStatusDisputed = 'disputed';
  static const String taskStatusPendingAcceptance = 'pending_acceptance';

  /// 以下状态后端不会主动返回，仅用于前端防御性处理（聊天页判断任务关闭等）
  static const String taskStatusExpired = 'expired';
  static const String taskStatusClosed = 'closed';

  // Application statuses（TaskApplication.status，不是 Task.status）
  static const String applicationStatusPending = 'pending';
  static const String applicationStatusChatting = 'chatting';
  static const String applicationStatusApproved = 'approved';
  static const String applicationStatusRejected = 'rejected';

  /// 任务来源
  static const String taskSourceNormal = 'normal';
  static const String taskSourceFleaMarket = 'flea_market';
  static const String taskSourceExpertService = 'expert_service';
  static const String taskSourceExpertActivity = 'expert_activity';

  /// 跳蚤市场商品状态
  static const String fleaMarketStatusActive = 'active';
  static const String fleaMarketStatusSold = 'sold';

  // Listing types
  static const String listingTypeSale = 'sale';
  static const String listingTypeRental = 'rental';

  // Rental units
  static const String rentalUnitDay = 'day';
  static const String rentalUnitWeek = 'week';
  static const String rentalUnitMonth = 'month';

  // Rental request statuses
  static const String rentalRequestPending = 'pending';
  static const String rentalRequestApproved = 'approved';
  static const String rentalRequestRejected = 'rejected';
  static const String rentalRequestCounterOffer = 'counter_offer';
  static const String rentalRequestExpired = 'expired';

  // Rental statuses
  static const String rentalStatusActive = 'active';
  static const String rentalStatusPendingReturn = 'pending_return';
  static const String rentalStatusReturned = 'returned';
  static const String rentalStatusOverdue = 'overdue';
  static const String rentalStatusDisputed = 'disputed';

  // Deposit statuses
  static const String depositHeld = 'held';
  static const String depositRefunded = 'refunded';
  static const String depositForfeited = 'forfeited';

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

  /// 支持的货币
  static const List<String> supportedCurrencies = ['GBP', 'EUR'];
  static const String defaultCurrency = 'GBP';
  static const String currencySymbol = '£'; // 保留向后兼容

  /// 根据货币代码返回符号 — 委托给 Helpers.currencySymbolFor
  static String currencySymbolFor(String currency) =>
      Helpers.currencySymbolFor(currency);

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
