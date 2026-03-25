import 'package:hive/hive.dart';

/// 任务发布草稿的本地存储服务（Hive）
/// 使用 Hive 原生 Map 存储（不做 jsonEncode），与项目缓存模式一致
class TaskDraftService {
  static const String _boxName = 'task_drafts';

  static Future<Box> _getBox() async {
    if (Hive.isBoxOpen(_boxName)) return Hive.box(_boxName);
    return Hive.openBox(_boxName);
  }

  /// 保存草稿（Hive 原生支持 Map 存储）
  static Future<void> saveDraft(Map<String, dynamic> draft) async {
    final box = await _getBox();
    draft['saved_at'] = DateTime.now().toIso8601String();
    await box.put('current_draft', draft);
  }

  /// 读取草稿
  static Future<Map<String, dynamic>?> loadDraft() async {
    final box = await _getBox();
    final raw = box.get('current_draft');
    if (raw == null) return null;
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return null;
  }

  /// 删除草稿
  static Future<void> deleteDraft() async {
    final box = await _getBox();
    await box.delete('current_draft');
  }

  /// 是否有草稿
  static Future<bool> hasDraft() async {
    final box = await _getBox();
    return box.containsKey('current_draft');
  }
}
