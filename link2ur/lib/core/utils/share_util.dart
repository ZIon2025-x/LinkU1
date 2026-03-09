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
  static String forumPostUrl(int postId) => '$_baseUrl/forum/post/$postId';
  static String fleaMarketUrl(String itemId) => '$_baseUrl/flea-market/$itemId';
  static String activityUrl(int activityId) => '$_baseUrl/activities/$activityId';
  static String leaderboardUrl(int leaderboardId) => '$_baseUrl/leaderboard/custom/$leaderboardId';
  static String leaderboardItemUrl(int itemId) => '$_baseUrl/leaderboard/item/$itemId';
  static String taskExpertUrl(String expertId) => '$_baseUrl/task-experts/$expertId';

  /// 统一分享入口
  ///
  /// 有 URL 时走 uri 模式（系统抓取 OG 标签生成链接卡片），
  /// 无 URL 时走 text 模式并附带首图文件。
  static Future<void> share({
    required String title,
    String description = '',
    String? url,
    String? imageUrl,
  }) async {
    // 有 URL 时走 uri 模式，不需要本地图片文件（OG 标签提供缩略图）
    if (url != null && url.trim().isNotEmpty) {
      await NativeShare.share(
        title: title,
        description: description,
        url: url,
      );
      return;
    }

    // 无 URL 时走 text 模式，附带首图
    final files = await NativeShare.fileFromFirstImageUrl(imageUrl);
    await NativeShare.share(
      title: title,
      description: description,
      files: files,
    );
  }
}
