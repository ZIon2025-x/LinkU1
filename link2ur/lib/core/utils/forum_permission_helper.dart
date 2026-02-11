import '../../data/models/forum.dart';
import '../../data/models/user.dart';

/// 论坛板块权限辅助工具
///
/// 集中管理板块可见性判断逻辑，对标 iOS ForumView.visibleCategories。
/// 后端 `/api/forum/forums/visible` 已做主要过滤，此类用于客户端兜底过滤。
class ForumPermissionHelper {
  const ForumPermissionHelper._();

  /// 判断某个板块对当前用户是否可见
  ///
  /// [category] 要判断的板块
  /// [user] 当前登录用户，null 表示未登录
  static bool isCategoryVisible(ForumCategory category, User? user) {
    final type = category.type;

    switch (type) {
      // 普通板块 — 所有人可见
      case ForumCategory.typeGeneral:
      case null: // type 为 null 视同 general
        return true;

      // 国家/地区级板块 — 需要学生认证
      case ForumCategory.typeRoot:
        return user?.isStudentVerified ?? false;

      // 学校专属板块 — 需要学生认证（后端已按学校过滤，这里只做兜底）
      case ForumCategory.typeUniversity:
        return user?.isStudentVerified ?? false;

      // ---- 预留未来权限类型 ----

      // 达人专属板块 — 需要达人身份
      case ForumCategory.typeExpert:
        return user?.isExpert ?? false;

      // 会员专属板块 — 需要 VIP 或超级会员
      case ForumCategory.typeVip:
        return _isVipOrAbove(user);

      // 超级会员专属板块 — 仅超级会员可见
      case ForumCategory.typeSuperVip:
        return _isSuperVip(user);

      // 未知类型默认可见（兼容未来新增类型）
      default:
        return true;
    }
  }

  /// 过滤出当前用户可见的板块列表
  ///
  /// [categories] 后端返回的板块列表
  /// [user] 当前登录用户，null 表示未登录
  static List<ForumCategory> filterVisibleCategories(
    List<ForumCategory> categories,
    User? user,
  ) {
    return categories
        .where((category) => isCategoryVisible(category, user))
        .toList();
  }

  /// 过滤出当前用户可发帖的板块列表（可见且非仅管理员发帖）
  ///
  /// [categories] 后端返回的板块列表
  /// [user] 当前登录用户，null 表示未登录
  static List<ForumCategory> filterPostableCategories(
    List<ForumCategory> categories,
    User? user,
  ) {
    return filterVisibleCategories(categories, user)
        .where((c) => !c.isAdminOnly)
        .toList();
  }

  /// 获取用户可见的板块 ID 集合（用于最新动态过滤）
  ///
  /// [categories] 后端返回的板块列表
  /// [user] 当前登录用户，null 表示未登录
  static Set<int> getVisibleCategoryIds(
    List<ForumCategory> categories,
    User? user,
  ) {
    return filterVisibleCategories(categories, user)
        .map((c) => c.id)
        .toSet();
  }

  /// 过滤出可见板块中的帖子
  ///
  /// [posts] 帖子列表
  /// [visibleCategoryIds] 可见板块 ID 集合
  static List<ForumPost> filterPostsByVisibleCategories(
    List<ForumPost> posts,
    Set<int> visibleCategoryIds,
  ) {
    if (visibleCategoryIds.isEmpty) return posts;
    return posts
        .where((post) => visibleCategoryIds.contains(post.categoryId))
        .toList();
  }

  // ==================== 内部辅助方法 ====================

  /// 是否是 VIP 或更高等级
  static bool _isVipOrAbove(User? user) {
    if (user == null) return false;
    final level = user.userLevel;
    return level == 'vip' || level == 'super';
  }

  /// 是否是超级会员
  static bool _isSuperVip(User? user) {
    if (user == null) return false;
    return user.userLevel == 'super';
  }
}
