import 'native_share.dart';

/// 分享链接与便捷分享入口
///
/// 统一各详情页的分享链接格式，与 iOS / 前端约定一致。
/// 便捷方法 [ShareUtil.share] 封装 [NativeShare]，
/// 便于一处修改分享行为（如追加 utm、换域名等）。
class ShareUtil {
  ShareUtil._();

  static const String _baseUrl = 'https://link2ur.com';

  static String taskUrl(int taskId) => '$_baseUrl/tasks/$taskId';
  static String forumPostUrl(int postId) => '$_baseUrl/forum/posts/$postId';
  static String fleaMarketUrl(String itemId) => '$_baseUrl/flea-market/$itemId';
  static String activityUrl(int activityId) => '$_baseUrl/activities/$activityId';
  static String leaderboardItemUrl(int itemId) => '$_baseUrl/leaderboard/item/$itemId';
  static String taskExpertUrl(String expertId) => '$_baseUrl/task-experts/$expertId';

  /// 统一分享入口：根据 [imageUrl] 拉取首图并调起系统分享
  static Future<void> share({
    required String title,
    String description = '',
    String? url,
    String? imageUrl,
  }) async {
    final files = await NativeShare.fileFromFirstImageUrl(imageUrl);
    await NativeShare.share(
      title: title,
      description: description,
      url: url,
      files: files,
    );
  }
}
